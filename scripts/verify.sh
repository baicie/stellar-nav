#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_root"

rust_toolchain="${RUST_TOOLCHAIN:-1.96.0}"
frb_version="${FRB_VERSION:-2.12.0}"
frb_wasm_toolchain="${FRB_WASM_TOOLCHAIN:-nightly-2026-08-01}"
wasm_pack_version="${WASM_PACK_VERSION:-0.15.0}"
cleanup_paths=()

cleanup() {
  local path

  if (( ${#cleanup_paths[@]} == 0 )); then
    return
  fi

  for path in "${cleanup_paths[@]}"; do
    case "$path" in
      "$project_root/.dart_tool/frb-"* | \
        "$project_root/native/astro_engine/src/frb_verify."*)
        if [[ -e "$path" ]]; then
          find "$path" -depth -delete
        fi
        ;;
      *)
        printf 'Refusing to clean unexpected path: %s\n' "$path" >&2
        ;;
    esac
  done
}

trap cleanup EXIT HUP INT TERM

step() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command_name in \
  cargo \
  dart \
  diff \
  flutter \
  flutter_rust_bridge_codegen \
  python3 \
  rustc \
  rustup \
  wasm-pack; do
  require_command "$command_name"
done

step "Toolchain versions"
flutter_info="$(flutter --version --machine)"
flutter_version="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["frameworkVersion"])' <<<"$flutter_info")"
dart_version="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["dartSdkVersion"])' <<<"$flutter_info")"
rust_version="$(rustc +"$rust_toolchain" --version | awk '{print $2}')"
installed_frb_version="$(flutter_rust_bridge_codegen --version | awk '{print $2}')"
installed_wasm_pack_version="$(wasm-pack --version | awk '{print $2}')"

if [[ "$flutter_version" != 3.44.* ]]; then
  printf 'Flutter 3.44.x is required, found %s.\n' "$flutter_version" >&2
  exit 1
fi

if [[ "$dart_version" != 3.12.* ]]; then
  printf 'Dart 3.12.x is required, found %s.\n' "$dart_version" >&2
  exit 1
fi

if [[ "$rust_version" != 1.96.* ]]; then
  printf 'Rust 1.96.x is required, found %s.\n' "$rust_version" >&2
  exit 1
fi

if [[ "$installed_frb_version" != "$frb_version" ]]; then
  printf 'flutter_rust_bridge_codegen %s is required, found %s.\n' \
    "$frb_version" "$installed_frb_version" >&2
  exit 1
fi

if [[ "$installed_wasm_pack_version" != "$wasm_pack_version" ]]; then
  printf 'wasm-pack %s is required, found %s.\n' \
    "$wasm_pack_version" "$installed_wasm_pack_version" >&2
  exit 1
fi

printf 'Flutter %s, Dart %s, Rust %s, FRB %s, wasm-pack %s\n' \
  "$flutter_version" \
  "$dart_version" \
  "$rust_version" \
  "$installed_frb_version" \
  "$installed_wasm_pack_version"

step "Dart format"
dart format --output=none --set-exit-if-changed lib test integration_test

step "Dart analysis"
dart analyze lib test integration_test

step "Rust host library for Flutter bridge smoke test"
cargo +"$rust_toolchain" build \
  --manifest-path native/Cargo.toml \
  --locked \
  --package astro_engine

step "Flutter tests"
flutter test --no-pub

step "Rust format"
cargo +"$rust_toolchain" fmt \
  --manifest-path native/Cargo.toml \
  --all \
  -- \
  --check

step "Rust Clippy"
cargo +"$rust_toolchain" clippy \
  --manifest-path native/Cargo.toml \
  --locked \
  --workspace \
  --all-targets \
  -- \
  -D warnings

step "Rust tests"
cargo +"$rust_toolchain" test \
  --manifest-path native/Cargo.toml \
  --locked \
  --workspace

step "Rust license notice tests"
python3 -m unittest discover -s tools/licenses/tests -v

step "Android release tooling tests"
python3 -m unittest discover -s tools/release/tests -p 'test_*.py' -v

release_version="$(
  sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml
)"
python3 -m tools.release.check_release --version "$release_version"

step "Release license consistency"
python3 tools/licenses/generate_rust_licenses.py --check
diff -u LICENSE native/astro_engine/LICENSE
diff -u LICENSE rust_builder/LICENSE

if [[ -f tools/data_pipeline/validate_catalog.py ]]; then
  step "Catalog validation"
  python3 tools/data_pipeline/validate_catalog.py data/solar_system_catalog.json

  step "Data pipeline tests"
  python3 -m unittest discover -s tools/data_pipeline/tests -v
fi

step "FRB generated binding consistency"
mkdir -p .dart_tool
dart_bindings_temp="$(mktemp -d "$project_root/.dart_tool/frb-bindings.XXXXXX")"
rust_bindings_temp="$(mktemp -d "$project_root/native/astro_engine/src/frb_verify.XXXXXX")"
cleanup_paths+=("$dart_bindings_temp" "$rust_bindings_temp")

flutter_rust_bridge_codegen generate \
  --rust-input crate::api \
  --rust-root native/astro_engine \
  --dart-root . \
  --dart-output "$dart_bindings_temp/lib/src/rust" \
  --rust-output "$rust_bindings_temp/frb_generated.rs" \
  --no-add-mod-to-lib \
  --no-auto-upgrade-dependency

diff -ru lib/src/rust "$dart_bindings_temp/lib/src/rust"
diff -u \
  native/astro_engine/src/frb_generated.rs \
  "$rust_bindings_temp/frb_generated.rs"

step "FRB web runtime consistency"
web_runtime_temp="$(mktemp -d "$project_root/.dart_tool/frb-web.XXXXXX")"
cleanup_paths+=("$web_runtime_temp")

flutter_rust_bridge_codegen build-web \
  --rust-root native/astro_engine \
  --output "$web_runtime_temp" \
  --wasm-pack-rustup-toolchain "$frb_wasm_toolchain" \
  --release

diff -ru --exclude=.gitignore web/pkg "$web_runtime_temp/pkg"

step "Flutter web release build"
flutter build web --release --no-pub

step "Web release license payload"
test -f build/web/pkg/LICENSE
test -f build/web/licenses/rust-third-party-licenses.txt
test -f build/web/assets/assets/fonts/OFL.txt
test -f build/web/assets/NOTICES

printf '\nAll verification gates passed.\n'
