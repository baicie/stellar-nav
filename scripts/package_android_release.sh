#!/usr/bin/env bash
# Build and verify three signed Android APKs, one for each supported ABI.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_root"

version_raw="${1:-}"
if [[ -z "$version_raw" ]]; then
  printf 'usage: %s VERSION\n' "$0" >&2
  exit 1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command_name in aapt apksigner flutter python3 sha256sum unzip; do
  if [[ "$command_name" == "aapt" || "$command_name" == "apksigner" ]]; then
    continue
  fi
  require_command "$command_name"
done

for variable_name in \
  ORG_GRADLE_PROJECT_ASTRONAV_UPLOAD_STORE_FILE \
  ORG_GRADLE_PROJECT_ASTRONAV_UPLOAD_STORE_PASSWORD \
  ORG_GRADLE_PROJECT_ASTRONAV_UPLOAD_KEY_ALIAS \
  ORG_GRADLE_PROJECT_ASTRONAV_UPLOAD_KEY_PASSWORD \
  ANDROID_EXPECTED_CERTIFICATE_SHA256; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'missing Android release environment variable: %s\n' \
      "$variable_name" >&2
    exit 1
  fi
done

store_file="$ORG_GRADLE_PROJECT_ASTRONAV_UPLOAD_STORE_FILE"
if [[ ! -s "$store_file" ]]; then
  printf 'Android release keystore is missing or empty: %s\n' "$store_file" >&2
  exit 1
fi

version="$(
  python3 -m tools.release.check_release \
    --project-root "$project_root" \
    --version "$version_raw" \
    --field version
)"
version_code="$(
  python3 -m tools.release.check_release \
    --project-root "$project_root" \
    --version "$version" \
    --field version_code
)"
expected_application_id="$(
  python3 -m tools.release.check_release \
    --project-root "$project_root" \
    --version "$version" \
    --field application_id
)"
expected_certificate="$(
  python3 -m tools.release.check_release \
    --project-root "$project_root" \
    --version "$version" \
    --field certificate_sha256
)"
provided_certificate="$(
  printf '%s' "$ANDROID_EXPECTED_CERTIFICATE_SHA256" |
    tr -d ':' |
    tr '[:lower:]' '[:upper:]'
)"
allow_test_certificate="${ANDROID_ALLOW_TEST_CERTIFICATE:-0}"
if [[ "$allow_test_certificate" == "1" ]]; then
  if [[ "${CI:-}" != "true" || "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    printf 'test certificates are allowed only in non-tag CI builds.\n' >&2
    exit 1
  fi
  expected_certificate="$provided_certificate"
elif [[ "$allow_test_certificate" != "0" ]]; then
  printf 'ANDROID_ALLOW_TEST_CERTIFICATE must be 0 or 1.\n' >&2
  exit 1
elif [[ "$provided_certificate" != "$expected_certificate" ]]; then
  printf 'ANDROID_EXPECTED_CERTIFICATE_SHA256 does not match release manifest.\n' >&2
  exit 1
fi

android_sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$android_sdk_root" || ! -d "$android_sdk_root/build-tools" ]]; then
  printf 'ANDROID_HOME or ANDROID_SDK_ROOT must contain Android build-tools.\n' >&2
  exit 1
fi
apksigner_path="$(
  find "$android_sdk_root/build-tools" -type f -name apksigner -print |
    sort -V |
    tail -n 1
)"
aapt_path="$(
  find "$android_sdk_root/build-tools" -type f -name aapt -print |
    sort -V |
    tail -n 1
)"
if [[ -z "$apksigner_path" || -z "$aapt_path" ]]; then
  printf 'Android build-tools must provide apksigner and aapt.\n' >&2
  exit 1
fi

printf '==> build signed split APKs for v%s (%s)\n' "$version" "$version_code"
flutter build apk \
  --release \
  --split-per-abi \
  --build-name "$version" \
  --build-number "$version_code"

output_dir="${RELEASE_OUTPUT_DIR:-$project_root/release/android}"
mkdir -p "$output_dir"
for output_name in \
  astro-nav-android-arm64-v8a.apk \
  astro-nav-android-armeabi-v7a.apk \
  astro-nav-android-x86_64.apk \
  SHA256SUMS.txt \
  release-metadata.json; do
  rm -f "$output_dir/$output_name"
done

abis=(arm64-v8a armeabi-v7a x86_64)
certificate=""
for abi in "${abis[@]}"; do
  source_path="$project_root/build/app/outputs/flutter-apk/app-${abi}-release.apk"
  target_path="$output_dir/astro-nav-android-${abi}.apk"
  if [[ ! -s "$source_path" ]]; then
    printf 'missing split APK for %s: %s\n' "$abi" "$source_path" >&2
    exit 1
  fi

  signer_output="$(
    LC_ALL=C "$apksigner_path" verify \
      --verbose \
      --print-certs-pem \
      "$source_path"
  )"
  apk_certificate="$(
    python3 -m tools.release.extract_certificate_sha256 <<<"$signer_output"
  )"
  if [[ "$apk_certificate" != "$expected_certificate" ]]; then
    printf '%s APK signing certificate does not match release manifest.\n' "$abi" >&2
    exit 1
  fi
  if [[ -z "$certificate" ]]; then
    certificate="$apk_certificate"
  elif [[ "$certificate" != "$apk_certificate" ]]; then
    printf 'split APK signing certificates are inconsistent.\n' >&2
    exit 1
  fi

  badging="$(LC_ALL=C "$aapt_path" dump badging "$source_path")"
  application_id="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")"
  apk_version_code="$(
    sed -n "s/^package: .*versionCode='\([^']*\)'.*/\1/p" <<<"$badging"
  )"
  apk_version_name="$(
    sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p" <<<"$badging"
  )"
  expected_apk_version_code="$(
    python3 -m tools.release.check_release \
      --project-root "$project_root" \
      --version "$version" \
      --field split_version_code \
      --abi "$abi"
  )"
  if [[ "$application_id" != "$expected_application_id" || \
    "$apk_version_code" != "$expected_apk_version_code" || \
    "$apk_version_name" != "$version" ]]; then
    printf '%s APK metadata mismatch.\n' "$abi" >&2
    printf 'actual: package=%s versionCode=%s versionName=%s\n' \
      "$application_id" "$apk_version_code" "$apk_version_name" >&2
    printf 'expected: package=%s versionCode=%s versionName=%s\n' \
      "$expected_application_id" "$expected_apk_version_code" "$version" >&2
    exit 1
  fi

  apk_entries="$(unzip -Z1 "$source_path")"
  apk_abis="$(
    awk -F/ '$1 == "lib" && NF >= 3 { print $2 }' <<<"$apk_entries" |
      sort -u
  )"
  if [[ "$apk_abis" != "$abi" ]]; then
    printf '%s APK must contain only its declared ABI; found: %s\n' \
      "$abi" "${apk_abis:-none}" >&2
    exit 1
  fi
  if ! grep -Fqx "lib/${abi}/libastro_engine.so" <<<"$apk_entries"; then
    printf '%s APK does not contain libastro_engine.so.\n' "$abi" >&2
    exit 1
  fi

  cp "$source_path" "$target_path"
done

metadata_certificate_arguments=()
if [[ "$allow_test_certificate" == "1" ]]; then
  metadata_certificate_arguments+=(--allow-test-certificate)
fi

python3 -m tools.release.write_package_metadata \
  --project-root "$project_root" \
  --version "$version" \
  --certificate "$certificate" \
  --output "$output_dir/release-metadata.json" \
  "${metadata_certificate_arguments[@]}" \
  --arm64-v8a "$output_dir/astro-nav-android-arm64-v8a.apk" \
  --armeabi-v7a "$output_dir/astro-nav-android-armeabi-v7a.apk" \
  --x86_64 "$output_dir/astro-nav-android-x86_64.apk"

(
  cd "$output_dir"
  sha256sum \
    astro-nav-android-arm64-v8a.apk \
    astro-nav-android-armeabi-v7a.apk \
    astro-nav-android-x86_64.apk \
    release-metadata.json >SHA256SUMS.txt
  sha256sum --check SHA256SUMS.txt
)

file_count="$(find "$output_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')"
if [[ "$file_count" != 5 ]]; then
  printf 'Android release directory must contain exactly 5 files; found %s.\n' \
    "$file_count" >&2
  exit 1
fi

printf 'OK: verified Android packages written to %s\n' "$output_dir"
