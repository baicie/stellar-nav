#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tomllib
from collections import deque
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_TARGET = "wasm32-unknown-unknown"
BUILD_STD_TOOLCHAIN = "nightly-2026-08-01"
BUILD_STD_RUSTC_COMMIT = "ad3d0bc141a02cf446e384136d250a1f6950fed5"
BUILD_STD_ROOTS = ("std", "panic_abort")
LICENSE_PREFIXES = (
    "COPYING",
    "COPYRIGHT",
    "LICENSE",
    "NOTICE",
    "UNLICENSE",
)


class LicenseNoticeError(RuntimeError):
    """Raised when the generated notice cannot be trusted."""


@dataclass(frozen=True)
class RegistryPackage:
    name: str
    version: str
    license_expression: str | None
    manifest_path: Path
    license_file: Path | None
    source: str

    @property
    def label(self) -> str:
        return f"{self.name} {self.version}"


@dataclass(frozen=True)
class LicenseOverride:
    path: Path
    source_url: str


@dataclass
class LicenseDocument:
    content: str
    packages: set[str]
    source_files: set[str]


@dataclass(frozen=True)
class BuildStdLicenseAssets:
    stdlib_copyright: str
    compiler_builtins_license: str


@dataclass(frozen=True)
class BuildStdLicenses:
    packages: tuple[RegistryPackage, ...]
    assets: BuildStdLicenseAssets
    toolchain: str
    rustc_commit: str
    roots: tuple[str, ...]


OVERRIDE_DIRECTORY = Path(__file__).resolve().parent / "overrides"
FLUTTER_RUST_BRIDGE_LICENSE = LicenseOverride(
    path=OVERRIDE_DIRECTORY / "flutter_rust_bridge-2.12.0-LICENSE",
    source_url=(
        "https://github.com/fzyzcjy/flutter_rust_bridge/"
        "blob/v2.12.0/LICENSE"
    ),
)
DEFAULT_OVERRIDES: Mapping[tuple[str, str], LicenseOverride] = {
    ("flutter_rust_bridge", "2.12.0"): FLUTTER_RUST_BRIDGE_LICENSE,
    ("flutter_rust_bridge_macros", "2.12.0"): FLUTTER_RUST_BRIDGE_LICENSE,
}


def parse_rustc_commit(version_output: str) -> str:
    match = re.search(
        r"^commit-hash:\s*([0-9a-f]{40})\s*$",
        version_output,
        re.MULTILINE,
    )
    if match is None:
        raise LicenseNoticeError("rustc -vV did not report a full commit hash")
    return match.group(1)


def require_rustc_commit(version_output: str, expected_commit: str) -> str:
    actual_commit = parse_rustc_commit(version_output)
    if actual_commit != expected_commit:
        raise LicenseNoticeError(
            f"rustc commit {actual_commit} does not match pinned commit {expected_commit}"
        )
    return actual_commit


def _read_text(path: Path, *, description: str) -> str:
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise LicenseNoticeError(f"cannot read {description} at {path}: {error}") from error
    normalized = _normalize_license_text(content)
    if not normalized.strip():
        raise LicenseNoticeError(f"{description} is empty: {path}")
    return normalized


def _normalize_license_text(content: str) -> str:
    """Canonicalize license text before it enters the generated notice."""
    normalized = content.replace("\r\n", "\n").replace("\r", "\n")
    normalized = "\n".join(line.rstrip(" \t") for line in normalized.split("\n"))
    return normalized.rstrip() + "\n"


def read_build_std_license_assets(sysroot: Path) -> BuildStdLicenseAssets:
    stdlib_path = sysroot / "share" / "doc" / "rust" / "COPYRIGHT-library.html"
    compiler_builtins_path = (
        sysroot
        / "lib"
        / "rustlib"
        / "src"
        / "rust"
        / "library"
        / "compiler-builtins"
        / "LICENSE.txt"
    )
    stdlib_copyright = _read_text(
        stdlib_path,
        description="Rust standard library copyright",
    )
    compiler_builtins_license = _read_text(
        compiler_builtins_path,
        description="compiler-builtins license",
    )

    stdlib_lower = stdlib_copyright.casefold()
    if not all(
        marker in stdlib_lower
        for marker in ("rust standard library", "apache", "mit")
    ):
        raise LicenseNoticeError(
            "Rust standard library copyright is incomplete: " + str(stdlib_path)
        )

    compiler_lower = compiler_builtins_license.casefold()
    if not all(
        marker in compiler_lower
        for marker in ("apache", "mit", "llvm", "exception")
    ):
        raise LicenseNoticeError(
            "compiler-builtins license is incomplete: " + str(compiler_builtins_path)
        )

    return BuildStdLicenseAssets(
        stdlib_copyright=stdlib_copyright,
        compiler_builtins_license=compiler_builtins_license,
    )


def _load_toml(path: Path, *, description: str) -> dict[str, Any]:
    try:
        with path.open("rb") as source:
            document = tomllib.load(source)
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise LicenseNoticeError(f"cannot read {description} at {path}: {error}") from error
    if not isinstance(document, dict):
        raise LicenseNoticeError(f"{description} is not a TOML table: {path}")
    return document


def _lock_package_key(package: Mapping[str, Any]) -> tuple[str, str, str]:
    name = package.get("name")
    version = package.get("version")
    source = package.get("source", "")
    if not isinstance(name, str) or not isinstance(version, str):
        raise LicenseNoticeError("rust-src Cargo.lock contains an invalid package")
    if not isinstance(source, str):
        raise LicenseNoticeError(f"rust-src package {name} {version} has an invalid source")
    return name, version, source


def _resolve_lock_dependency(
    dependency: str,
    packages_by_name: Mapping[str, list[tuple[str, str, str]]],
) -> tuple[str, str, str]:
    name, separator, remainder = dependency.partition(" ")
    candidates = packages_by_name.get(name, [])
    if not candidates:
        raise LicenseNoticeError(
            f"rust-src Cargo.lock references missing dependency {dependency}"
        )
    if not separator:
        if len(candidates) != 1:
            raise LicenseNoticeError(
                f"rust-src Cargo.lock dependency {dependency} is ambiguous"
            )
        return candidates[0]

    version, _, raw_source = remainder.partition(" ")
    source = raw_source.removeprefix("(").removesuffix(")")
    matches = [
        candidate
        for candidate in candidates
        if candidate[1] == version and (not source or candidate[2] == source)
    ]
    if len(matches) != 1:
        raise LicenseNoticeError(
            f"rust-src Cargo.lock dependency {dependency} cannot be resolved uniquely"
        )
    return matches[0]


def _manifest_license_package(
    manifest_path: Path,
    *,
    expected_name: str,
    expected_version: str,
    source: str,
    fallback_license_file: Path | None = None,
) -> RegistryPackage:
    manifest = _load_toml(manifest_path, description="rust-src package manifest")
    package = manifest.get("package")
    if not isinstance(package, dict):
        raise LicenseNoticeError(f"package table is missing from {manifest_path}")
    name = package.get("name")
    version = package.get("version")
    if name != expected_name or version != expected_version:
        raise LicenseNoticeError(
            f"rust-src manifest identity does not match {expected_name} {expected_version}: "
            f"{manifest_path}"
        )
    license_expression = package.get("license")
    if license_expression is not None and not isinstance(license_expression, str):
        raise LicenseNoticeError(
            f"rust-src package {expected_name} {expected_version} has an invalid license"
        )
    raw_license_file = package.get("license-file")
    if raw_license_file is not None and not isinstance(raw_license_file, str):
        raise LicenseNoticeError(
            f"rust-src package {expected_name} {expected_version} has an invalid license-file"
        )
    license_file = Path(raw_license_file) if raw_license_file is not None else None
    if license_file is None:
        license_file = fallback_license_file

    return RegistryPackage(
        name=expected_name,
        version=expected_version,
        license_expression=license_expression,
        manifest_path=manifest_path,
        license_file=license_file,
        source=source,
    )


def _has_license_document(directory: Path) -> bool:
    try:
        return any(
            path.is_file() and _is_license_document(path)
            for path in directory.iterdir()
        )
    except OSError as error:
        raise LicenseNoticeError(
            f"cannot inspect rust-src vendor directory {directory}: {error}"
        ) from error


def _packages_from_build_std_lock(
    library: Path,
    *,
    toolchain: str,
    stdlib_copyright: str,
) -> tuple[RegistryPackage, ...]:
    lock = _load_toml(library / "Cargo.lock", description="rust-src Cargo.lock")
    raw_packages = lock.get("package")
    if not isinstance(raw_packages, list):
        raise LicenseNoticeError("rust-src Cargo.lock has no package records")

    packages_by_key: dict[tuple[str, str, str], Mapping[str, Any]] = {}
    packages_by_name: dict[str, list[tuple[str, str, str]]] = {}
    for raw_package in raw_packages:
        if not isinstance(raw_package, dict):
            raise LicenseNoticeError("rust-src Cargo.lock contains an invalid package")
        key = _lock_package_key(raw_package)
        if key in packages_by_key:
            raise LicenseNoticeError(
                f"rust-src Cargo.lock contains duplicate package {key[0]} {key[1]}"
            )
        packages_by_key[key] = raw_package
        packages_by_name.setdefault(key[0], []).append(key)

    pending: deque[tuple[str, str, str]] = deque()
    for root in BUILD_STD_ROOTS:
        root_candidates = packages_by_name.get(root, [])
        if len(root_candidates) != 1:
            raise LicenseNoticeError(
                f"rust-src Cargo.lock must contain one build-std root named {root}"
            )
        pending.append(root_candidates[0])

    reachable: set[tuple[str, str, str]] = set()
    while pending:
        key = pending.popleft()
        if key in reachable:
            continue
        reachable.add(key)
        dependencies = packages_by_key[key].get("dependencies", [])
        if not isinstance(dependencies, list) or not all(
            isinstance(dependency, str) for dependency in dependencies
        ):
            raise LicenseNoticeError(
                f"rust-src package {key[0]} {key[1]} has invalid dependencies"
            )
        pending.extend(
            _resolve_lock_dependency(dependency, packages_by_name)
            for dependency in dependencies
        )

    stdlib_notice_path = (
        library.parents[4] / "share" / "doc" / "rust" / "COPYRIGHT-library.html"
    )
    selected: list[RegistryPackage] = []
    for name, version, source in sorted(reachable):
        if source:
            if not source.startswith("registry+"):
                raise LicenseNoticeError(
                    f"unsupported rust-src dependency source for {name} {version}: {source}"
                )
            manifest_path = library / "vendor" / f"{name}-{version}" / "Cargo.toml"
            crate_directory = manifest_path.parent
            fallback = None
            if not _has_license_document(crate_directory):
                package_marker = f"{name}-{version}"
                if package_marker not in stdlib_copyright:
                    fallback = None
                else:
                    fallback = stdlib_notice_path
            selected.append(
                _manifest_license_package(
                    manifest_path,
                    expected_name=name,
                    expected_version=version,
                    source=source,
                    fallback_license_file=fallback,
                )
            )
        elif name == "compiler_builtins":
            selected.append(
                _manifest_license_package(
                    library
                    / "compiler-builtins"
                    / "compiler-builtins"
                    / "Cargo.toml",
                    expected_name=name,
                    expected_version=version,
                    source=f"rust-src+{toolchain}",
                    fallback_license_file=library
                    / "compiler-builtins"
                    / "LICENSE.txt",
                )
            )

    return tuple(
        sorted(selected, key=lambda package: (package.name, package.version, package.source))
    )


def load_build_std_licenses(
    sysroot: Path,
    *,
    toolchain: str = BUILD_STD_TOOLCHAIN,
    rustc_commit: str = BUILD_STD_RUSTC_COMMIT,
) -> BuildStdLicenses:
    if toolchain != BUILD_STD_TOOLCHAIN:
        raise LicenseNoticeError(
            f"build-std toolchain must remain pinned to {BUILD_STD_TOOLCHAIN}"
        )
    if rustc_commit != BUILD_STD_RUSTC_COMMIT:
        raise LicenseNoticeError(
            f"build-std rustc commit must remain pinned to {BUILD_STD_RUSTC_COMMIT}"
        )
    assets = read_build_std_license_assets(sysroot)
    library = sysroot / "lib" / "rustlib" / "src" / "rust" / "library"
    packages = _packages_from_build_std_lock(
        library,
        toolchain=toolchain,
        stdlib_copyright=assets.stdlib_copyright,
    )
    if not packages:
        raise LicenseNoticeError("build-std graph contains no third-party packages")
    return BuildStdLicenses(
        packages=packages,
        assets=assets,
        toolchain=toolchain,
        rustc_commit=rustc_commit,
        roots=BUILD_STD_ROOTS,
    )


def packages_from_metadata(metadata: dict[str, Any]) -> list[RegistryPackage]:
    resolve = metadata.get("resolve")
    workspace_members = metadata.get("workspace_members")
    raw_packages = metadata.get("packages")
    if not isinstance(resolve, dict) or not isinstance(workspace_members, list):
        raise LicenseNoticeError("cargo metadata is missing its resolve graph")
    if not isinstance(raw_packages, list):
        raise LicenseNoticeError("cargo metadata is missing package records")

    nodes = resolve.get("nodes")
    if not isinstance(nodes, list):
        raise LicenseNoticeError("cargo metadata is missing resolve nodes")

    dependencies_by_id: dict[str, list[str]] = {}
    for node in nodes:
        if not isinstance(node, dict) or not isinstance(node.get("id"), str):
            raise LicenseNoticeError("cargo metadata contains an invalid resolve node")
        dependencies: list[str] = []
        for dependency in node.get("deps", []):
            if not isinstance(dependency, dict) or not isinstance(
                dependency.get("pkg"), str
            ):
                raise LicenseNoticeError(
                    "cargo metadata contains an invalid dependency edge"
                )
            dependencies.append(dependency["pkg"])
        dependencies_by_id[node["id"]] = dependencies

    reachable: set[str] = set()
    pending = deque(sorted(workspace_members))
    while pending:
        package_id = pending.popleft()
        if package_id in reachable:
            continue
        reachable.add(package_id)
        pending.extend(dependencies_by_id.get(package_id, []))

    packages: list[RegistryPackage] = []
    for raw_package in raw_packages:
        if not isinstance(raw_package, dict):
            raise LicenseNoticeError("cargo metadata contains an invalid package")
        package_id = raw_package.get("id")
        source = raw_package.get("source")
        if package_id not in reachable or source is None:
            continue
        required_strings = {
            key: raw_package.get(key)
            for key in ("name", "version", "manifest_path")
        }
        if not all(isinstance(value, str) for value in required_strings.values()):
            raise LicenseNoticeError("cargo metadata package fields are incomplete")
        if not isinstance(source, str):
            raise LicenseNoticeError("cargo metadata package source is invalid")

        raw_license_file = raw_package.get("license_file")
        if raw_license_file is not None and not isinstance(raw_license_file, str):
            raise LicenseNoticeError("cargo metadata license_file is invalid")
        raw_license = raw_package.get("license")
        if raw_license is not None and not isinstance(raw_license, str):
            raise LicenseNoticeError("cargo metadata license expression is invalid")

        packages.append(
            RegistryPackage(
                name=required_strings["name"],
                version=required_strings["version"],
                license_expression=raw_license,
                manifest_path=Path(required_strings["manifest_path"]),
                license_file=(
                    Path(raw_license_file) if raw_license_file is not None else None
                ),
                source=source,
            )
        )

    return sorted(packages, key=lambda package: (package.name, package.version))


def _is_license_document(path: Path) -> bool:
    upper_name = path.name.upper()
    return any(
        upper_name == prefix
        or upper_name.startswith(f"{prefix}-")
        or upper_name.startswith(f"{prefix}.")
        for prefix in LICENSE_PREFIXES
    )


def _license_sources(
    package: RegistryPackage,
    overrides: Mapping[tuple[str, str], LicenseOverride],
) -> list[tuple[Path, str]]:
    crate_directory = package.manifest_path.parent
    paths: set[Path] = set()
    if package.license_file is not None:
        explicit_path = package.license_file
        if not explicit_path.is_absolute():
            explicit_path = crate_directory / explicit_path
        paths.add(explicit_path)

    if crate_directory.is_dir():
        paths.update(
            path
            for path in crate_directory.iterdir()
            if path.is_file() and _is_license_document(path)
        )

    existing_paths = sorted(
        (path for path in paths if path.is_file()),
        key=lambda path: path.name.casefold(),
    )
    if existing_paths:
        return [
            (path, f"{package.label}/{path.name}") for path in existing_paths
        ]

    override = overrides.get((package.name, package.version))
    if override is None:
        raise LicenseNoticeError(
            f"{package.label} does not ship a license or notice document"
        )
    if not override.path.is_file():
        raise LicenseNoticeError(
            f"audited license override is missing for {package.label}: {override.path}"
        )
    return [
        (
            override.path,
            f"{package.label}/audited repository override: {override.source_url}",
        )
    ]


def _normalized_text(path: Path, package: RegistryPackage) -> str:
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise LicenseNoticeError(
            f"cannot read {path.name} for {package.label}: {error}"
        ) from error
    return _normalize_license_text(content)


def _merge_packages(
    workspace_packages: list[RegistryPackage],
    build_std_packages: tuple[RegistryPackage, ...],
) -> list[RegistryPackage]:
    merged: dict[tuple[str, str, str], RegistryPackage] = {}
    for package in [*workspace_packages, *build_std_packages]:
        key = package.name, package.version, package.source
        existing = merged.get(key)
        if existing is not None:
            if existing.license_expression != package.license_expression:
                raise LicenseNoticeError(
                    f"conflicting license declarations for {package.label}"
                )
            continue
        merged[key] = package
    return sorted(
        merged.values(),
        key=lambda package: (package.name, package.version, package.source),
    )


def render_notice(
    packages: list[RegistryPackage],
    *,
    target: str,
    overrides: Mapping[tuple[str, str], LicenseOverride] | None = None,
    build_std: BuildStdLicenses | None = None,
) -> str:
    all_packages = _merge_packages(
        packages,
        build_std.packages if build_std is not None else (),
    )
    if not all_packages:
        raise LicenseNoticeError("the Rust dependency graph contains no third-party packages")

    effective_overrides = DEFAULT_OVERRIDES if overrides is None else overrides
    documents: dict[str, LicenseDocument] = {}
    for package in all_packages:
        if not package.license_expression and package.license_file is None:
            raise LicenseNoticeError(
                f"{package.label} has neither a license expression nor license_file"
            )
        for path, source_label in _license_sources(package, effective_overrides):
            content = _normalized_text(path, package)
            digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
            document = documents.setdefault(
                digest,
                LicenseDocument(content=content, packages=set(), source_files=set()),
            )
            document.packages.add(package.label)
            document.source_files.add(source_label)

    if build_std is not None:
        content = build_std.assets.stdlib_copyright
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        document = documents.setdefault(
            digest,
            LicenseDocument(content=content, packages=set(), source_files=set()),
        )
        document.packages.add(
            "Rust Standard Library "
            + build_std.toolchain
            + " (build-std roots: "
            + ", ".join(build_std.roots)
            + ")"
        )
        document.source_files.add(
            f"Rust {build_std.toolchain}/COPYRIGHT-library.html"
        )

    lines = [
        "RUST THIRD-PARTY LICENSES",
        "",
        "Generated file. Do not edit by hand.",
        "Source: cargo metadata --locked --filter-platform " + target,
        (
            "Exact-version audited repository overrides are labeled when a "
            "crate archive omits its declared license text."
        ),
        f"Target: {target}",
    ]
    if build_std is not None:
        lines.extend(
            [
                f"Build-std toolchain: {build_std.toolchain}",
                f"Build-std rustc commit: {build_std.rustc_commit}",
                "Build-std roots: " + ", ".join(build_std.roots),
                (
                    "Build-std source: rust-src library/Cargo.lock and "
                    "official toolchain license assets"
                ),
                f"Build-std third-party packages: {len(build_std.packages)}",
            ]
        )
    lines.extend(
        [
            f"Packages: {len(all_packages)}",
            "",
            "PACKAGE INVENTORY",
            "",
        ]
    )
    for package in all_packages:
        expression = package.license_expression or "license_file"
        lines.append(f"- {package.label} | {expression} | {package.source}")

    lines.extend(["", "LICENSE AND NOTICE DOCUMENTS", ""])
    divider = "=" * 80
    for digest, document in sorted(documents.items()):
        lines.extend(
            [
                divider,
                f"Document SHA-256: {digest}",
                "Used by:",
                *(f"- {label}" for label in sorted(document.packages)),
                "Source files:",
                *(f"- {path}" for path in sorted(document.source_files)),
                divider,
                "",
                document.content.rstrip(),
                "",
            ]
        )

    return "\n".join(lines).rstrip() + "\n"


def sync_notice(output: Path, content: str, *, check: bool) -> None:
    if check:
        try:
            current = output.read_text(encoding="utf-8")
        except FileNotFoundError as error:
            raise LicenseNoticeError(f"{output} is missing") from error
        if current != content:
            raise LicenseNoticeError(
                f"{output} is out of date; regenerate the Rust license notice"
            )
        return

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content, encoding="utf-8")


def load_metadata(manifest_path: Path, *, target: str) -> dict[str, Any]:
    command = [
        "cargo",
        "metadata",
        "--manifest-path",
        str(manifest_path),
        "--locked",
        "--filter-platform",
        target,
        "--format-version",
        "1",
    ]
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        metadata = json.loads(completed.stdout)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        raise LicenseNoticeError(f"cargo metadata failed: {error}") from error
    if not isinstance(metadata, dict):
        raise LicenseNoticeError("cargo metadata returned a non-object document")
    return metadata


def _run_rustc(arguments: list[str]) -> str:
    command = ["rustc", f"+{BUILD_STD_TOOLCHAIN}", *arguments]
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except (OSError, subprocess.CalledProcessError) as error:
        detail = getattr(error, "stderr", None) or str(error)
        raise LicenseNoticeError(
            f"pinned build-std rustc command failed: {detail}"
        ) from error
    return completed.stdout


def load_pinned_build_std_licenses() -> BuildStdLicenses:
    version_output = _run_rustc(["-vV"])
    rustc_commit = require_rustc_commit(version_output, BUILD_STD_RUSTC_COMMIT)
    raw_sysroot = _run_rustc(["--print", "sysroot"]).strip()
    if not raw_sysroot or "\n" in raw_sysroot:
        raise LicenseNoticeError("pinned build-std rustc returned an invalid sysroot")
    sysroot = Path(raw_sysroot)
    if not sysroot.is_dir():
        raise LicenseNoticeError(f"pinned build-std sysroot is missing: {sysroot}")
    return load_build_std_licenses(
        sysroot,
        toolchain=BUILD_STD_TOOLCHAIN,
        rustc_commit=rustc_commit,
    )


def parse_args(arguments: list[str]) -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Generate deterministic Rust license notices for the Web release."
    )
    parser.add_argument(
        "--manifest-path",
        type=Path,
        default=project_root / "native" / "Cargo.toml",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=project_root
        / "web"
        / "licenses"
        / "rust-third-party-licenses.txt",
    )
    parser.add_argument("--target", default=DEFAULT_TARGET)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    options = parse_args(sys.argv[1:] if arguments is None else arguments)
    try:
        metadata = load_metadata(options.manifest_path, target=options.target)
        packages = packages_from_metadata(metadata)
        build_std = load_pinned_build_std_licenses()
        notice = render_notice(
            packages,
            target=options.target,
            build_std=build_std,
        )
        sync_notice(options.output, notice, check=options.check)
    except LicenseNoticeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
