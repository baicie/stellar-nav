import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]
RELEASE_SCRIPT = PROJECT_ROOT / "scripts/release.sh"
RELEASE_TOOL = PROJECT_ROOT / "tools/release"
CERTIFICATE_SHA256 = (
    "D4:CC:2E:B0:73:4E:E8:38:FF:1E:0A:B3:69:EF:2A:64:B8:FA:89:C2:C3:AD:93:47:"
    "9F:47:86:9A:A6:D5:DA:18"
)


class ReleaseScriptTests(unittest.TestCase):
    def test_dry_run_validates_without_creating_tag(self) -> None:
        with self._fixture() as fixture:
            result = self._run_release(fixture, "0.0.1-beta.0", "--dry-run")

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("dry-run: no tag created", result.stdout)
            self.assertEqual(self._git(fixture.project, "tag", "--list"), "")

    def test_creates_and_pushes_annotated_prerelease_tag(self) -> None:
        with self._fixture() as fixture:
            result = self._run_release(fixture, "v0.0.1-beta.0")

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                self._git(fixture.project, "cat-file", "-t", "v0.0.1-beta.0"),
                "tag",
            )
            self.assertEqual(
                self._git(
                    fixture.project,
                    "--git-dir",
                    str(fixture.remote),
                    "rev-parse",
                    "refs/tags/v0.0.1-beta.0^{}",
                ),
                self._git(fixture.project, "rev-parse", "HEAD"),
            )

    def test_rejects_non_main_dirty_and_unpushed_sources(self) -> None:
        with self._fixture() as fixture:
            self._git(fixture.project, "switch", "-c", "codex/not-main")
            result = self._run_release(fixture, "0.0.1-beta.0", "--dry-run")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must be on main", result.stderr)

        with self._fixture() as fixture:
            (fixture.project / "DIRTY").write_text("dirty\n", encoding="utf-8")
            result = self._run_release(fixture, "0.0.1-beta.0", "--dry-run")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("working tree not clean", result.stderr)

        with self._fixture() as fixture:
            (fixture.project / "README.md").write_text("ahead\n", encoding="utf-8")
            self._git(fixture.project, "add", "README.md")
            self._git(fixture.project, "commit", "-m", "test: local only")
            result = self._run_release(fixture, "0.0.1-beta.0", "--dry-run")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("does not match origin/main", result.stderr)

    class _Fixture:
        def __init__(self, root: Path, project: Path, remote: Path):
            self.root = root
            self.project = project
            self.remote = remote

        def __enter__(self):
            return self

        def __exit__(self, _type, _value, _traceback):
            shutil.rmtree(self.root)

    def _fixture(self) -> "ReleaseScriptTests._Fixture":
        root = Path(tempfile.mkdtemp(prefix="astro-nav-release-test."))
        project = root / "project"
        remote = root / "remote.git"
        (project / "scripts").mkdir(parents=True)
        (project / "tools").mkdir(parents=True)
        (project / "android/app").mkdir(parents=True)
        (project / "docs/releases").mkdir(parents=True)
        shutil.copy2(RELEASE_SCRIPT, project / "scripts/release.sh")
        shutil.copytree(RELEASE_TOOL, project / "tools/release")
        (project / "scripts/verify.sh").write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\necho fixture verification passed\n",
            encoding="utf-8",
        )
        os.chmod(project / "scripts/release.sh", 0o755)
        os.chmod(project / "scripts/verify.sh", 0o755)
        (project / "pubspec.yaml").write_text(
            "name: astro_nav\nversion: 0.0.1-beta.0+1\n",
            encoding="utf-8",
        )
        (project / "android/app/build.gradle.kts").write_text(
            'android { defaultConfig { applicationId = "com.baicie.astro_nav" } }\n',
            encoding="utf-8",
        )
        (project / "docs/releases/android-manifest.json").write_text(
            "{\n"
            '  "schemaVersion": 1,\n'
            '  "applicationId": "com.baicie.astro_nav",\n'
            f'  "certificateSha256": "{CERTIFICATE_SHA256}",\n'
            '  "releases": [{"version": "0.0.1-beta.0", "versionCode": 1}]\n'
            "}\n",
            encoding="utf-8",
        )
        (project / "docs/releases/0.0.1-beta.0.md").write_text(
            "# AstroNav v0.0.1-beta.0\n",
            encoding="utf-8",
        )
        (project / "README.md").write_text("fixture\n", encoding="utf-8")
        (project / ".gitignore").write_text(
            "__pycache__/\n*.py[cod]\n",
            encoding="utf-8",
        )

        subprocess.run(
            ["git", "init", "--bare", "--initial-branch=main", str(remote)],
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["git", "init", "--initial-branch=main", str(project)],
            check=True,
            capture_output=True,
            text=True,
        )
        self._git(project, "config", "user.name", "Release Test")
        self._git(project, "config", "user.email", "release-test@example.invalid")
        self._git(project, "add", ".")
        self._git(project, "commit", "-m", "test: create fixture")
        self._git(project, "remote", "add", "origin", str(remote))
        self._git(project, "push", "--set-upstream", "origin", "main")
        return self._Fixture(root, project, remote)

    def _run_release(self, fixture: _Fixture, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(fixture.project / "scripts/release.sh"), *arguments],
            cwd=fixture.project,
            check=False,
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "RELEASE_REMOTE": "origin",
                "RELEASE_BRANCH": "main",
            },
        )

    @staticmethod
    def _git(cwd: Path, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=cwd,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()


if __name__ == "__main__":
    unittest.main()
