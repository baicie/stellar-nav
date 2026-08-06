from __future__ import annotations

import binascii
import hashlib
import json
import re
import ssl
from dataclasses import dataclass
from pathlib import Path


VERSION_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)"
    r"(?:-((?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?$"
)
CERTIFICATE_PATTERN = re.compile(r"^[0-9A-F]{64}$")
CERTIFICATE_PEM_PATTERN = re.compile(
    r"-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----"
)
PUBSPEC_VERSION_PATTERN = re.compile(
    r"^version:\s*([^\s#+]+)(?:\+([1-9]\d*))?\s*(?:#.*)?$", re.MULTILINE
)
APPLICATION_ID_PATTERN = re.compile(r'applicationId\s*=\s*"([A-Za-z0-9_.]+)"')

ANDROID_ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")
ANDROID_ASSET_NAMES = tuple(
    f"astro-nav-android-{abi}.apk" for abi in ANDROID_ABIS
) + ("SHA256SUMS.txt", "release-metadata.json")


class ReleaseConfigError(ValueError):
    """Raised when repository release metadata is unsafe or inconsistent."""


@dataclass(frozen=True)
class ReleaseConfig:
    version: str
    version_code: int
    application_id: str
    certificate_sha256: str
    release_notes: Path

    @property
    def tag(self) -> str:
        return f"v{self.version}"

    @property
    def is_prerelease(self) -> bool:
        return "-" in self.version

    @property
    def asset_names(self) -> tuple[str, ...]:
        return ANDROID_ASSET_NAMES


def normalize_version(value: str) -> str:
    version = value.removeprefix("v")
    if not VERSION_PATTERN.fullmatch(version):
        raise ReleaseConfigError(
            f"Release version must be SemVer without build metadata: {value}"
        )
    return version


def normalize_certificate_sha256(value: str) -> str:
    fingerprint = value.replace(":", "").upper()
    if not CERTIFICATE_PATTERN.fullmatch(fingerprint):
        raise ReleaseConfigError(
            f"Android certificate fingerprint must be a SHA-256 value: {value}"
        )
    return fingerprint


def extract_single_certificate_sha256(output: str) -> str:
    certificates = CERTIFICATE_PEM_PATTERN.findall(output)
    if len(certificates) != 1:
        raise ReleaseConfigError(
            "apksigner output must contain exactly one signing certificate; "
            f"found {len(certificates)}."
        )
    try:
        der_certificate = ssl.PEM_cert_to_DER_cert(certificates[0])
    except (ValueError, binascii.Error) as error:
        raise ReleaseConfigError(
            "apksigner output contains an invalid signing certificate."
        ) from error
    return hashlib.sha256(der_certificate).hexdigest().upper()


def load_release_config(project_root: Path, requested_version: str) -> ReleaseConfig:
    root = project_root.resolve()
    version = normalize_version(requested_version)
    pubspec_version, build_number = _read_pubspec_version(root / "pubspec.yaml")
    if version != pubspec_version:
        raise ReleaseConfigError(
            f"The requested release {version} does not match pubspec {pubspec_version}."
        )

    application_id = _read_application_id(root / "android/app/build.gradle.kts")
    manifest = _read_json_object(root / "docs/releases/android-manifest.json")
    if manifest.get("schemaVersion") != 1:
        raise ReleaseConfigError("Android release manifest schemaVersion must be 1.")
    if manifest.get("applicationId") != application_id:
        raise ReleaseConfigError(
            "Android release manifest applicationId does not match build.gradle.kts."
        )

    certificate_value = manifest.get("certificateSha256")
    if not isinstance(certificate_value, str):
        raise ReleaseConfigError(
            "Android release manifest certificateSha256 must be a string."
        )
    certificate_sha256 = normalize_certificate_sha256(certificate_value)

    releases = manifest.get("releases")
    if not isinstance(releases, list):
        raise ReleaseConfigError("Android release manifest releases must be an array.")
    matching_releases = [
        entry
        for entry in releases
        if isinstance(entry, dict) and entry.get("version") == version
    ]
    if len(matching_releases) != 1:
        raise ReleaseConfigError(
            f"Android release manifest must contain exactly one entry for {version}."
        )

    _validate_release_history(releases)
    version_code = matching_releases[0].get("versionCode")
    if not isinstance(version_code, int) or isinstance(version_code, bool):
        raise ReleaseConfigError(f"Android {version} versionCode must be an integer.")
    if version_code != build_number:
        raise ReleaseConfigError(
            f"Android manifest versionCode {version_code} does not match "
            f"pubspec build number {build_number}."
        )

    release_notes = root / "docs/releases" / f"{version}.md"
    if not release_notes.is_file() or not release_notes.read_text(
        encoding="utf-8"
    ).strip():
        raise ReleaseConfigError(f"Missing release notes: {release_notes}")

    return ReleaseConfig(
        version=version,
        version_code=version_code,
        application_id=application_id,
        certificate_sha256=certificate_sha256,
        release_notes=release_notes,
    )


def render_release_metadata(
    config: ReleaseConfig, artifacts: dict[str, Path]
) -> str:
    if tuple(artifacts) != ANDROID_ABIS:
        raise ReleaseConfigError(
            f"Android artifacts must use ABI order: {', '.join(ANDROID_ABIS)}."
        )

    artifact_entries = []
    for abi, path in artifacts.items():
        if not path.is_file() or path.stat().st_size <= 0:
            raise ReleaseConfigError(f"Missing Android artifact for {abi}: {path}")
        artifact_entries.append(
            {
                "abi": abi,
                "file": path.name,
                "sha256": _sha256(path),
                "sizeBytes": path.stat().st_size,
            }
        )

    document = {
        "schemaVersion": 1,
        "version": config.version,
        "tag": config.tag,
        "versionCode": config.version_code,
        "applicationId": config.application_id,
        "certificateSha256": config.certificate_sha256,
        "prerelease": config.is_prerelease,
        "artifacts": artifact_entries,
    }
    return f"{json.dumps(document, ensure_ascii=False, indent=2)}\n"


def _read_pubspec_version(path: Path) -> tuple[str, int]:
    match = PUBSPEC_VERSION_PATTERN.search(path.read_text(encoding="utf-8"))
    if match is None:
        raise ReleaseConfigError("pubspec.yaml must define version VERSION+BUILD_NUMBER.")
    version = normalize_version(match.group(1))
    if match.group(2) is None:
        raise ReleaseConfigError("pubspec.yaml release version must include a build number.")
    return version, int(match.group(2))


def _read_application_id(path: Path) -> str:
    matches = APPLICATION_ID_PATTERN.findall(path.read_text(encoding="utf-8"))
    if len(matches) != 1:
        raise ReleaseConfigError(
            "android/app/build.gradle.kts must define exactly one applicationId."
        )
    return matches[0]


def _read_json_object(path: Path) -> dict[str, object]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseConfigError(f"Invalid Android release manifest: {error}") from error
    if not isinstance(document, dict):
        raise ReleaseConfigError("Android release manifest must be a JSON object.")
    return document


def _validate_release_history(releases: list[object]) -> None:
    versions: set[str] = set()
    version_codes: set[int] = set()
    previous_version: str | None = None
    previous_version_code: int | None = None
    for entry in releases:
        if not isinstance(entry, dict):
            raise ReleaseConfigError("Every Android release entry must be an object.")
        raw_version = entry.get("version")
        version_code = entry.get("versionCode")
        if not isinstance(raw_version, str):
            raise ReleaseConfigError("Every Android release version must be a string.")
        version = normalize_version(raw_version)
        if version in versions:
            raise ReleaseConfigError(f"Duplicate Android release version: {version}")
        if (
            not isinstance(version_code, int)
            or isinstance(version_code, bool)
            or version_code < 1
        ):
            raise ReleaseConfigError(
                f"Android {version} versionCode must be a positive integer."
            )
        if version_code in version_codes:
            raise ReleaseConfigError(
                f"Duplicate Android release versionCode: {version_code}"
            )
        if previous_version is not None and _compare_versions(
            version, previous_version
        ) <= 0:
            raise ReleaseConfigError(
                f"Android release version must increase after {previous_version}: "
                f"{version}"
            )
        if previous_version_code is not None and version_code <= previous_version_code:
            raise ReleaseConfigError(
                "Android versionCode must increase after "
                f"{previous_version_code}: {version_code}"
            )
        versions.add(version)
        version_codes.add(version_code)
        previous_version = version
        previous_version_code = version_code


def _compare_versions(left: str, right: str) -> int:
    left_match = VERSION_PATTERN.fullmatch(left)
    right_match = VERSION_PATTERN.fullmatch(right)
    if left_match is None or right_match is None:
        raise ReleaseConfigError("Cannot compare invalid release versions.")

    left_core = tuple(int(left_match.group(index)) for index in range(1, 4))
    right_core = tuple(int(right_match.group(index)) for index in range(1, 4))
    if left_core != right_core:
        return -1 if left_core < right_core else 1

    left_prerelease = left_match.group(4)
    right_prerelease = right_match.group(4)
    if left_prerelease is None or right_prerelease is None:
        if left_prerelease == right_prerelease:
            return 0
        return 1 if left_prerelease is None else -1

    left_identifiers = left_prerelease.split(".")
    right_identifiers = right_prerelease.split(".")
    for left_identifier, right_identifier in zip(
        left_identifiers, right_identifiers, strict=False
    ):
        if left_identifier == right_identifier:
            continue
        left_numeric = left_identifier.isdigit()
        right_numeric = right_identifier.isdigit()
        if left_numeric and right_numeric:
            return -1 if int(left_identifier) < int(right_identifier) else 1
        if left_numeric != right_numeric:
            return -1 if left_numeric else 1
        return -1 if left_identifier < right_identifier else 1
    if len(left_identifiers) == len(right_identifiers):
        return 0
    return -1 if len(left_identifiers) < len(right_identifiers) else 1


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
