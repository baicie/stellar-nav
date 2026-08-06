import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]


class WorkflowContractTests(unittest.TestCase):
    def test_workflows_use_node_24_github_actions(self) -> None:
        checkout = (
            "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 "
            "# v7.0.1"
        )
        for workflow_name in ("ci.yml", "release.yml"):
            workflow = (
                PROJECT_ROOT / ".github/workflows" / workflow_name
            ).read_text(encoding="utf-8")
            self.assertIn(checkout, workflow)
            self.assertNotIn("actions/checkout@11d5960a", workflow)

        ci_workflow = (PROJECT_ROOT / ".github/workflows/ci.yml").read_text(
            encoding="utf-8"
        )
        release_workflow = (
            PROJECT_ROOT / ".github/workflows/release.yml"
        ).read_text(encoding="utf-8")
        upload = (
            "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a "
            "# v7.0.1"
        )
        download = (
            "actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c "
            "# v8.0.1"
        )
        self.assertIn(upload, ci_workflow)
        self.assertIn(upload, release_workflow)
        self.assertIn(download, release_workflow)
        self.assertNotIn("actions/upload-artifact@ea165f8d", ci_workflow)
        self.assertNotIn("actions/upload-artifact@ea165f8d", release_workflow)
        self.assertNotIn("actions/download-artifact@634f93cb", release_workflow)

    def test_ci_builds_split_release_packages_with_an_ephemeral_key(self) -> None:
        workflow = (PROJECT_ROOT / ".github/workflows/ci.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("Build Android release smoke packages", workflow)
        self.assertIn("keytool -genkeypair", workflow)
        self.assertIn("./scripts/package_android_release.sh", workflow)
        self.assertIn("--split-per-abi", self._package_script())
        self.assertNotIn("secrets.ANDROID_", workflow)
        self.assertIn("overwrite: true", workflow)

    def test_release_workflow_signs_attests_and_publishes_a_prerelease(self) -> None:
        workflow = (PROJECT_ROOT / ".github/workflows/release.yml").read_text(
            encoding="utf-8"
        )

        for secret_name in (
            "ANDROID_KEYSTORE_BASE64",
            "ANDROID_KEYSTORE_PASSWORD",
            "ANDROID_KEY_ALIAS",
            "ANDROID_KEY_PASSWORD",
        ):
            self.assertIn(f"secrets.{secret_name}", workflow)
        self.assertIn("./scripts/package_android_release.sh", workflow)
        self.assertIn("actions/attest-build-provenance", workflow)
        self.assertIn("gh release create", workflow)
        self.assertIn("--prerelease", workflow)
        self.assertNotIn("--clobber", workflow)
        self.assertIn("outputs.certificate_sha256", workflow)
        self.assertNotIn("outputs.certificate-sha256", workflow)
        self.assertNotIn('>> "${GITHUB_ENV}"', workflow)
        self.assertNotIn("/immutable-releases", workflow)
        self.assertIn("--draft", workflow)
        self.assertIn("--draft=false", workflow)
        self.assertIn(
            "--json assets,body,isDraft,isImmutable,isPrerelease,name,url",
            workflow,
        )
        self.assertNotIn("releases/tags/${RELEASE_TAG}", workflow)
        self.assertIn("grep -Fqx 'release not found'", workflow)
        self.assertIn("Existing published release state is inconsistent.", workflow)
        self.assertIn("Unable to determine whether the release exists.", workflow)
        self.assertIn("verify_remote_release_tag()", workflow)
        self.assertIn("refs/release-verification/", workflow)
        self.assertIn('"${GITHUB_SHA}"', workflow)
        self.assertGreaterEqual(workflow.count("verify_remote_release_tag"), 3)
        self.assertIn("trap 'rm -f", workflow)
        self.assertIn("overwrite: true", workflow)
        self.assertNotIn("Restore protected release keystore", workflow)

        for asset_name in (
            "astro-nav-android-arm64-v8a.apk",
            "astro-nav-android-armeabi-v7a.apk",
            "astro-nav-android-x86_64.apk",
            "SHA256SUMS.txt",
            "release-metadata.json",
        ):
            self.assertIn(asset_name, workflow)

    def test_package_script_fails_closed_and_verifies_every_binary_contract(self) -> None:
        script = self._package_script()

        for required_command in (
            "flutter build apk",
            "--split-per-abi",
            "apksigner",
            "aapt",
            "sha256sum",
            "ANDROID_EXPECTED_CERTIFICATE_SHA256",
            "libastro_engine.so",
            "--field split_version_code",
        ):
            self.assertIn(required_command, script)
        self.assertIn("tr '[:lower:]' '[:upper:]'", script)
        self.assertNotIn("${provided_certificate^^}", script)
        self.assertNotIn("app-release.apk", script)
        self.assertNotIn("debug.keystore", script)
        self.assertNotIn("--no-pub", script)

    def test_cargokit_uses_gradle_nine_exec_operations(self) -> None:
        plugin = (PROJECT_ROOT / "rust_builder/cargokit/gradle/plugin.gradle").read_text(
            encoding="utf-8"
        )

        self.assertIn("ExecOperations", plugin)
        self.assertIn("getExecOperations()", plugin)
        self.assertIn("execOperations.exec", plugin)
        self.assertNotIn("project.exec", plugin)

    def test_native_android_plugin_tracks_the_app_compile_sdk(self) -> None:
        build_file = (
            PROJECT_ROOT / "rust_builder/android/build.gradle"
        ).read_text(encoding="utf-8")

        self.assertIn(
            'compileSdkVersion rootProject.project(":app").android.compileSdkVersion',
            build_file,
        )
        self.assertNotIn("compileSdkVersion 33", build_file)

    @staticmethod
    def _package_script() -> str:
        return (PROJECT_ROOT / "scripts/package_android_release.sh").read_text(
            encoding="utf-8"
        )


if __name__ == "__main__":
    unittest.main()
