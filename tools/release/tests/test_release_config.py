import json
import tempfile
import unittest
from pathlib import Path

from tools.release.release_config import (
    ANDROID_ABIS,
    ReleaseConfigError,
    extract_single_certificate_sha256,
    load_release_config,
    normalize_certificate_sha256,
    normalize_version,
    render_release_metadata,
)


CERTIFICATE_SHA256 = (
    "D4:CC:2E:B0:73:4E:E8:38:FF:1E:0A:B3:69:EF:2A:64:"
    "B8:FA:89:C2:C3:AD:93:47:9F:47:86:9A:A6:D5:DA:18"
)
CERTIFICATE_PEM = """-----BEGIN CERTIFICATE-----
MIICvjCCAaYCCQDtR5T/Z7ujmzANBgkqhkiG9w0BAQsFADAhMR8wHQYDVQQDDBZT
dGVsbGFyIE5hdiBDSSBGaXh0dXJlMB4XDTI2MDgwNTA3MzU1NVoXDTM2MDgwMjA3
MzU1NVowITEfMB0GA1UEAwwWU3RlbGxhciBOYXYgQ0kgRml4dHVyZTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBAOFvzOlw+i6KQe3hn8QN0kiE/bmtaPO9
F3xNLGjnK69fESyJMkv/L8FGEkPCVtS+x9g9qojCu2Y8XQSwdD7nOfy89QutChnI
f2KDH2k1IBsD0FcP15gt9gcIBq94Dff0GmB7HzBR2vvRF3H9x8dMpv8vtcEOf3yb
QSNLqHqbLmARDgqbgonOO8CGTgbcapRHkobHP9jcxO0/Vg3GoDa77ueSEG4LnYaH
cCodRTjieE/8j7hH+Xmav/5J2x3vxnf9wmfgI0SV9cA9Pk4U/FOSE/cz7aPMWD/R
qKmUVpIbqS5SU7duT+pxPDcVrzFwvMXmIpX3Bj3Doz4pwB6iq75wTrECAwEAATAN
BgkqhkiG9w0BAQsFAAOCAQEAY39+xI7Azn7kcRzk9VNHBx58dQHpI+Jsh2ILiMCG
thhDqKxCIwTG4yM50LH1t7/IOisISvpURTR0cOINH+hZ0rIWW1HoX9n3wvMQY/2W
kTCLk9ud2w87IVPbIph3vvOz7JgynjHsJu7xIoUWLf+TkHC6jFjXpGDynY6PPttQ
dpti6GH/Pk6Xuu3ucheMVV+3Ybw109rHuQJrBSEb5iJzCGAtekm3ADzCAGUSLaWE
URr8GoQ37NQTiUV9JGY48vkgn32ZU7rj+5q0OkDlgeQsqloZsjRvjMDG3X1pBB57
JFRDWM5E6CMNn7eiiLmAMrAzFaSsR8SreW02K+3iRv+b8w==
-----END CERTIFICATE-----"""


class ReleaseConfigTests(unittest.TestCase):
    def test_accepts_semver_prerelease_and_rejects_build_metadata_in_tag(self) -> None:
        self.assertEqual(normalize_version("v0.0.1-beta.0"), "0.0.1-beta.0")
        self.assertEqual(normalize_version("1.2.3-rc.12"), "1.2.3-rc.12")

        with self.assertRaisesRegex(ReleaseConfigError, "SemVer"):
            normalize_version("0.0.1-beta.0+1")
        with self.assertRaisesRegex(ReleaseConfigError, "SemVer"):
            normalize_version("01.0.0-beta.0")

    def test_normalizes_android_certificate_fingerprint(self) -> None:
        self.assertEqual(
            normalize_certificate_sha256(CERTIFICATE_SHA256.lower()),
            CERTIFICATE_SHA256.replace(":", ""),
        )

        with self.assertRaisesRegex(ReleaseConfigError, "SHA-256"):
            normalize_certificate_sha256("not-a-certificate")

    def test_extracts_exactly_one_signing_certificate_from_apksigner_pem(self) -> None:
        output = f"Verified using v3 scheme: true\n{CERTIFICATE_PEM}\n"
        self.assertEqual(
            extract_single_certificate_sha256(output),
            "2854EEF761FF49240742D302E2EFF8FC7552791FE364CB555657E631B56DE2F6",
        )
        with self.assertRaisesRegex(ReleaseConfigError, "exactly one"):
            extract_single_certificate_sha256("no certificate")
        with self.assertRaisesRegex(ReleaseConfigError, "exactly one"):
            extract_single_certificate_sha256(f"{CERTIFICATE_PEM}\n{CERTIFICATE_PEM}")

    def test_loads_matching_flutter_android_release_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)

            config = load_release_config(root, "v0.0.1-beta.0")

            self.assertEqual(config.version, "0.0.1-beta.0")
            self.assertEqual(config.tag, "v0.0.1-beta.0")
            self.assertEqual(config.version_code, 1)
            self.assertEqual(config.application_id, "com.baicie.astro_nav")
            self.assertTrue(config.is_prerelease)
            self.assertEqual(
                config.asset_names,
                (
                    "astro-nav-android-arm64-v8a.apk",
                    "astro-nav-android-armeabi-v7a.apk",
                    "astro-nav-android-x86_64.apk",
                    "SHA256SUMS.txt",
                    "release-metadata.json",
                ),
            )

    def test_derives_flutter_abi_split_version_codes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)
            config = load_release_config(root, "0.0.1-beta.0")

            self.assertEqual(config.split_version_code("armeabi-v7a"), 1001)
            self.assertEqual(config.split_version_code("arm64-v8a"), 2001)
            self.assertEqual(config.split_version_code("x86_64"), 4001)
            with self.assertRaisesRegex(ReleaseConfigError, "Unsupported Android ABI"):
                config.split_version_code("x86")

    def test_release_metadata_records_split_version_codes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)
            config = load_release_config(root, "0.0.1-beta.0")
            artifacts = {}
            for abi in ANDROID_ABIS:
                artifact = root / f"{abi}.apk"
                artifact.write_bytes(f"{abi}\n".encode("ascii"))
                artifacts[abi] = artifact

            metadata = json.loads(render_release_metadata(config, artifacts))

            self.assertEqual(metadata["versionCode"], 1)
            self.assertEqual(
                [entry["versionCode"] for entry in metadata["artifacts"]],
                [2001, 1001, 4001],
            )

    def test_rejects_mismatched_version_build_number_and_application_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)

            (root / "pubspec.yaml").write_text(
                "name: astro_nav\nversion: 0.0.1-beta.1+1\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ReleaseConfigError, "requested release"):
                load_release_config(root, "0.0.1-beta.0")

            self._write_fixture(root)
            (root / "pubspec.yaml").write_text(
                "name: astro_nav\nversion: 0.0.1-beta.0+2\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ReleaseConfigError, "versionCode"):
                load_release_config(root, "0.0.1-beta.0")

            self._write_fixture(root)
            (root / "android/app/build.gradle.kts").write_text(
                'android { defaultConfig { applicationId = "com.example.wrong" } }\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ReleaseConfigError, "applicationId"):
                load_release_config(root, "0.0.1-beta.0")

    def test_requires_release_notes_and_a_unique_manifest_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)
            (root / "docs/releases/0.0.1-beta.0.md").unlink()

            with self.assertRaisesRegex(ReleaseConfigError, "release notes"):
                load_release_config(root, "0.0.1-beta.0")

            self._write_fixture(root)
            manifest_path = root / "docs/releases/android-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["releases"].append(manifest["releases"][0])
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            with self.assertRaisesRegex(ReleaseConfigError, "exactly one"):
                load_release_config(root, "0.0.1-beta.0")

    def test_release_history_requires_increasing_semver_and_version_code(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._write_fixture(root)
            manifest_path = root / "docs/releases/android-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["releases"] = [
                {"version": "0.0.1-beta.1", "versionCode": 2},
                {"version": "0.0.1-beta.0", "versionCode": 1},
            ]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            with self.assertRaisesRegex(ReleaseConfigError, "version must increase"):
                load_release_config(root, "0.0.1-beta.0")

            self._write_fixture(root)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["releases"] = [
                {"version": "0.0.1-beta.0", "versionCode": 2},
                {"version": "0.0.1-beta.1", "versionCode": 1},
            ]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            (root / "pubspec.yaml").write_text(
                "name: astro_nav\nversion: 0.0.1-beta.1+1\n",
                encoding="utf-8",
            )
            (root / "docs/releases/0.0.1-beta.1.md").write_text(
                "# AstroNav v0.0.1-beta.1\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ReleaseConfigError, "versionCode must increase"):
                load_release_config(root, "0.0.1-beta.1")

    def _write_fixture(self, root: Path) -> None:
        (root / "android/app").mkdir(parents=True, exist_ok=True)
        (root / "docs/releases").mkdir(parents=True, exist_ok=True)
        (root / "pubspec.yaml").write_text(
            "name: astro_nav\nversion: 0.0.1-beta.0+1\n",
            encoding="utf-8",
        )
        (root / "android/app/build.gradle.kts").write_text(
            'android { defaultConfig { applicationId = "com.baicie.astro_nav" } }\n',
            encoding="utf-8",
        )
        (root / "docs/releases/android-manifest.json").write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "applicationId": "com.baicie.astro_nav",
                    "certificateSha256": CERTIFICATE_SHA256,
                    "releases": [
                        {"version": "0.0.1-beta.0", "versionCode": 1}
                    ],
                }
            ),
            encoding="utf-8",
        )
        (root / "docs/releases/0.0.1-beta.0.md").write_text(
            "# AstroNav v0.0.1-beta.0\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    unittest.main()
