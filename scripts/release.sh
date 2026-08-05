#!/usr/bin/env bash
# Create and push an annotated v* tag after validating the release metadata.
#
# Usage:
#   ./scripts/release.sh 0.0.2
#   ./scripts/release.sh v0.0.2 --dry-run
#   ./scripts/release.sh 0.0.2 --message "Release v0.0.2"
#
# Env:
#   RELEASE_BRANCH   default: main
#   RELEASE_REMOTE   default: origin
set -euo pipefail

REMOTE="${RELEASE_REMOTE:-origin}"
BRANCH="${RELEASE_BRANCH:-main}"
DRY_RUN=0
MESSAGE=""
VERSION_RAW=""

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -m|--message) MESSAGE="${2:?missing value for --message}"; shift 2 ;;
    -*) echo "unknown flag: $1" >&2; usage 1 ;;
    *)
      if [[ -n "$VERSION_RAW" ]]; then
        echo "unexpected argument: $1" >&2
        usage 1
      fi
      VERSION_RAW="$1"
      shift
      ;;
  esac
done

[[ -n "$VERSION_RAW" ]] || { echo "version required, e.g. 0.0.2" >&2; usage 1; }

VERSION="${VERSION_RAW#v}"
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "invalid stable semver: $VERSION_RAW (expected X.Y.Z)" >&2
  exit 1
fi
TAG="v${VERSION}"
MESSAGE="${MESSAGE:-Release ${TAG}}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$BRANCH" ]]; then
  echo "must be on ${BRANCH} (currently: ${current_branch:-detached})" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree not clean; commit or stash first" >&2
  git status --short
  exit 1
fi

echo "==> fetch ${REMOTE}"
git fetch "$REMOTE" --tags --prune

local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "${REMOTE}/${BRANCH}")"
if [[ "$local_sha" != "$remote_sha" ]]; then
  echo "local ${BRANCH} (${local_sha:0:7}) != ${REMOTE}/${BRANCH} (${remote_sha:0:7})" >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "tag already exists locally: $TAG" >&2
  exit 1
fi
if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "tag already exists on ${REMOTE}: $TAG" >&2
  exit 1
fi

RELEASE_VERSION="$VERSION" pnpm check:release

echo "==> release plan"
echo "    branch: ${BRANCH} @ $(git rev-parse --short HEAD)"
echo "    tag:    ${TAG}"
echo "    effect: push annotated tag -> Android Release workflow"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> dry-run: no tag created"
  exit 0
fi

echo "==> create annotated tag ${TAG}"
git tag -a "$TAG" -m "$MESSAGE"
echo "==> push ${TAG} to ${REMOTE}"
git push "$REMOTE" "$TAG"

owner_repo="$(git remote get-url "$REMOTE" | sed -E 's#.*(github\.com[:/])##;s#\.git$##')"
echo "OK: ${TAG} pushed"
echo "  Actions: https://github.com/${owner_repo}/actions/workflows/release.yml"
echo "  Release: https://github.com/${owner_repo}/releases/tag/${TAG}"
