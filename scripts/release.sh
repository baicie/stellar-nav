#!/usr/bin/env bash
# Validate, tag, and push an Android prerelease from the protected release branch.
#
# Usage:
#   ./scripts/release.sh 0.0.1-beta.0
#   ./scripts/release.sh v0.0.1-beta.0 --dry-run
#   ./scripts/release.sh 0.0.1-beta.0 --message "AstroNav v0.0.1-beta.0"
set -euo pipefail

remote="${RELEASE_REMOTE:-origin}"
branch="${RELEASE_BRANCH:-main}"
dry_run=0
message=""
version_raw=""

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (( $# > 0 )); do
  case "$1" in
    -h|--help)
      usage 0
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -m|--message)
      message="${2:?missing value for --message}"
      shift 2
      ;;
    -*)
      printf 'unknown flag: %s\n' "$1" >&2
      usage 1
      ;;
    *)
      if [[ -n "$version_raw" ]]; then
        printf 'unexpected argument: %s\n' "$1" >&2
        usage 1
      fi
      version_raw="$1"
      shift
      ;;
  esac
done

if [[ -z "$version_raw" ]]; then
  printf 'version required, for example 0.0.1-beta.0\n' >&2
  usage 1
fi

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_root"

version="$(
  python3 -m tools.release.check_release \
    --project-root "$project_root" \
    --version "$version_raw" \
    --field version
)"
tag="v${version}"
message="${message:-Release ${tag}}"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$branch" ]]; then
  printf 'must be on %s (currently: %s)\n' \
    "$branch" "${current_branch:-detached}" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  printf 'working tree not clean; commit or stash first\n' >&2
  git status --short >&2
  exit 1
fi

printf '==> fetch %s/%s and tags\n' "$remote" "$branch"
git fetch "$remote" "$branch" --tags --prune

local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "${remote}/${branch}")"
if [[ "$local_sha" != "$remote_sha" ]]; then
  printf 'local %s %s does not match %s/%s %s\n' \
    "$branch" "${local_sha:0:7}" "$remote" "$branch" "${remote_sha:0:7}" >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/tags/${tag}"; then
  printf 'tag already exists locally: %s\n' "$tag" >&2
  exit 1
fi
if git ls-remote --exit-code --tags "$remote" "refs/tags/${tag}" >/dev/null 2>&1; then
  printf 'tag already exists on %s: %s\n' "$remote" "$tag" >&2
  exit 1
fi

printf '==> release plan\n'
printf '    branch: %s @ %s\n' "$branch" "$(git rev-parse --short HEAD)"
printf '    tag:    %s\n' "$tag"
printf '    effect: push annotated tag and publish signed split Android APKs\n'

if (( dry_run == 1 )); then
  printf '==> dry-run: no tag created\n'
  exit 0
fi

printf '==> run full verification\n'
./scripts/verify.sh

if [[ "$(git rev-parse HEAD)" != "$local_sha" ]]; then
  printf 'HEAD changed during release verification; refusing to tag.\n' >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  printf 'verification changed the working tree; refusing to tag.\n' >&2
  git status --short >&2
  exit 1
fi

printf '==> create annotated tag %s\n' "$tag"
git tag -a "$tag" -m "$message"
printf '==> push %s to %s\n' "$tag" "$remote"
git push "$remote" "$tag"

owner_repo="$(
  git remote get-url "$remote" |
    sed -E 's#.*github\.com[:/]##; s#\.git$##'
)"
printf 'OK: %s pushed\n' "$tag"
printf '  Actions: https://github.com/%s/actions/workflows/release.yml\n' "$owner_repo"
printf '  Release: https://github.com/%s/releases/tag/%s\n' "$owner_repo" "$tag"
