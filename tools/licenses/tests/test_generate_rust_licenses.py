from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.licenses import generate_rust_licenses


class RustLicenseGenerationTests(unittest.TestCase):
    def _build_std_fixture(self, root: Path) -> Path:
        sysroot = root / "nightly-toolchain"
        library = sysroot / "lib" / "rustlib" / "src" / "rust" / "library"
        library.mkdir(parents=True)
        (library / "Cargo.lock").write_text(
            """version = 4

[[package]]
name = "std"
version = "0.0.0"
dependencies = [
 "compiler_builtins",
 "core",
 "reachable",
]

[[package]]
name = "panic_abort"
version = "0.0.0"
dependencies = ["core"]

[[package]]
name = "core"
version = "0.0.0"

[[package]]
name = "compiler_builtins"
version = "0.1.160"
dependencies = ["core"]

[[package]]
name = "reachable"
version = "1.2.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
dependencies = ["transitive"]

[[package]]
name = "transitive"
version = "2.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"

[[package]]
name = "unused"
version = "9.9.9"
source = "registry+https://github.com/rust-lang/crates.io-index"
""",
            encoding="utf-8",
        )

        for name, version in (
            ("reachable", "1.2.3"),
            ("transitive", "2.0.0"),
            ("unused", "9.9.9"),
        ):
            crate = library / "vendor" / f"{name}-{version}"
            crate.mkdir(parents=True)
            (crate / "Cargo.toml").write_text(
                f'[package]\nname = "{name}"\nversion = "{version}"\nlicense = "MIT"\n',
                encoding="utf-8",
            )
            (crate / "LICENSE-MIT").write_text(
                f"MIT license for {name}\n",
                encoding="utf-8",
            )

        compiler_builtins = library / "compiler-builtins"
        compiler_manifest = compiler_builtins / "compiler-builtins"
        compiler_manifest.mkdir(parents=True)
        (compiler_manifest / "Cargo.toml").write_text(
            """[package]
name = "compiler_builtins"
version = "0.1.160"
license = "MIT AND Apache-2.0 WITH LLVM-exception"
""",
            encoding="utf-8",
        )
        (compiler_builtins / "LICENSE.txt").write_text(
            "compiler-builtins license text\n"
            "MIT AND Apache-2.0 WITH LLVM-exception\n",
            encoding="utf-8",
        )

        rust_docs = sysroot / "share" / "doc" / "rust"
        rust_docs.mkdir(parents=True)
        (rust_docs / "COPYRIGHT-library.html").write_text(
            "Copyright notices for The Rust Standard Library\n"
            "Apache 2.0 and MIT\n"
            "Rust standard library copyright and license text\n",
            encoding="utf-8",
        )
        return sysroot

    def test_parses_and_requires_the_pinned_rustc_commit(self) -> None:
        version_output = """rustc 1.99.0-nightly (ad3d0bc14 2026-07-31)
commit-hash: ad3d0bc141a02cf446e384136d250a1f6950fed5
commit-date: 2026-07-31
"""

        self.assertEqual(
            generate_rust_licenses.parse_rustc_commit(version_output),
            "ad3d0bc141a02cf446e384136d250a1f6950fed5",
        )
        with self.assertRaisesRegex(
            generate_rust_licenses.LicenseNoticeError,
            "does not match",
        ):
            generate_rust_licenses.require_rustc_commit(
                version_output,
                "0000000000000000000000000000000000000000",
            )

    def test_reads_official_build_std_license_assets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = Path(temporary_directory)
            rust_docs = sysroot / "share" / "doc" / "rust"
            compiler_builtins = (
                sysroot
                / "lib"
                / "rustlib"
                / "src"
                / "rust"
                / "library"
                / "compiler-builtins"
            )
            rust_docs.mkdir(parents=True)
            compiler_builtins.mkdir(parents=True)
            rust_docs.joinpath("COPYRIGHT-library.html").write_text(
                "Copyright notices for The Rust Standard Library\n"
                "Apache 2.0 and MIT\n",
                encoding="utf-8",
            )
            compiler_builtins.joinpath("LICENSE.txt").write_text(
                "MIT AND Apache-2.0 WITH LLVM-exception\n",
                encoding="utf-8",
            )

            assets = generate_rust_licenses.read_build_std_license_assets(
                sysroot
            )

        self.assertIn("Rust Standard Library", assets.stdlib_copyright)
        self.assertIn("LLVM-exception", assets.compiler_builtins_license)

    def test_rejects_incomplete_build_std_license_assets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = Path(temporary_directory)
            rust_docs = sysroot / "share" / "doc" / "rust"
            compiler_builtins = (
                sysroot
                / "lib"
                / "rustlib"
                / "src"
                / "rust"
                / "library"
                / "compiler-builtins"
            )
            rust_docs.mkdir(parents=True)
            compiler_builtins.mkdir(parents=True)
            rust_docs.joinpath("COPYRIGHT-library.html").write_text(
                "incomplete\n",
                encoding="utf-8",
            )
            compiler_builtins.joinpath("LICENSE.txt").write_text(
                "incomplete\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                generate_rust_licenses.LicenseNoticeError,
                "standard library copyright",
            ):
                generate_rust_licenses.read_build_std_license_assets(sysroot)

    def test_selects_only_reachable_registry_packages(self) -> None:
        metadata = {
            "workspace_members": ["workspace-root"],
            "packages": [
                {
                    "id": "workspace-root",
                    "name": "astro_engine",
                    "version": "0.1.0",
                    "license": "MIT",
                    "license_file": None,
                    "manifest_path": "/repo/native/astro_engine/Cargo.toml",
                    "source": None,
                },
                {
                    "id": "serde-id",
                    "name": "serde",
                    "version": "1.0.0",
                    "license": "MIT OR Apache-2.0",
                    "license_file": None,
                    "manifest_path": "/cargo/serde/Cargo.toml",
                    "source": "registry+https://github.com/rust-lang/crates.io-index",
                },
                {
                    "id": "unused-id",
                    "name": "unused",
                    "version": "9.9.9",
                    "license": "MIT",
                    "license_file": None,
                    "manifest_path": "/cargo/unused/Cargo.toml",
                    "source": "registry+https://github.com/rust-lang/crates.io-index",
                },
            ],
            "resolve": {
                "nodes": [
                    {
                        "id": "workspace-root",
                        "deps": [{"pkg": "serde-id"}],
                    },
                    {"id": "serde-id", "deps": []},
                    {"id": "unused-id", "deps": []},
                ]
            },
        }

        packages = generate_rust_licenses.packages_from_metadata(metadata)

        self.assertEqual(
            [(package.name, package.version) for package in packages],
            [("serde", "1.0.0")],
        )

    def test_render_deduplicates_identical_license_documents(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            alpha = root / "alpha"
            beta = root / "beta"
            alpha.mkdir()
            beta.mkdir()
            shared_text = "Shared MIT license text\n"
            (alpha / "LICENSE-MIT").write_text(shared_text, encoding="utf-8")
            (beta / "LICENSE-MIT").write_text(shared_text, encoding="utf-8")
            (beta / "NOTICE").write_text(
                "Beta copyright notice\n",
                encoding="utf-8",
            )
            packages = [
                generate_rust_licenses.RegistryPackage(
                    name="alpha",
                    version="1.0.0",
                    license_expression="MIT",
                    manifest_path=alpha / "Cargo.toml",
                    license_file=None,
                    source="registry+example",
                ),
                generate_rust_licenses.RegistryPackage(
                    name="beta",
                    version="2.0.0",
                    license_expression="MIT",
                    manifest_path=beta / "Cargo.toml",
                    license_file=None,
                    source="registry+example",
                ),
            ]

            notice = generate_rust_licenses.render_notice(
                packages,
                target="wasm32-unknown-unknown",
            )

        self.assertEqual(notice.count(shared_text), 1)
        self.assertIn("alpha 1.0.0", notice)
        self.assertIn("beta 2.0.0", notice)
        self.assertIn("Beta copyright notice", notice)

    def test_render_normalizes_per_line_trailing_whitespace(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            crate_directory = Path(temporary_directory)
            (crate_directory / "LICENSE-MIT").write_bytes(
                b"First line  \r\n"
                b"\t  \r\n"
                b"Last line\t\r\n"
            )
            package = generate_rust_licenses.RegistryPackage(
                name="whitespace-license",
                version="1.0.0",
                license_expression="MIT",
                manifest_path=crate_directory / "Cargo.toml",
                license_file=None,
                source="registry+example",
            )

            notice = generate_rust_licenses.render_notice(
                [package],
                target="wasm32-unknown-unknown",
            )

        self.assertFalse(
            any(line.endswith((" ", "\t")) for line in notice.splitlines())
        )
        self.assertIn("First line\n\nLast line\n", notice)

    def test_missing_license_document_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            crate_directory = Path(temporary_directory)
            package = generate_rust_licenses.RegistryPackage(
                name="missing-license",
                version="1.0.0",
                license_expression="MIT",
                manifest_path=crate_directory / "Cargo.toml",
                license_file=None,
                source="registry+example",
            )

            with self.assertRaisesRegex(
                generate_rust_licenses.LicenseNoticeError,
                "missing-license 1.0.0",
            ):
                generate_rust_licenses.render_notice(
                    [package],
                    target="wasm32-unknown-unknown",
                )

    def test_exact_version_override_is_labeled_in_notice(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            crate_directory = root / "crate"
            crate_directory.mkdir()
            override = root / "LICENSE"
            override.write_text("Audited upstream license\n", encoding="utf-8")
            package = generate_rust_licenses.RegistryPackage(
                name="missing-license",
                version="1.0.0",
                license_expression="MIT",
                manifest_path=crate_directory / "Cargo.toml",
                license_file=None,
                source="registry+example",
            )

            notice = generate_rust_licenses.render_notice(
                [package],
                target="wasm32-unknown-unknown",
                overrides={
                    ("missing-license", "1.0.0"): generate_rust_licenses.LicenseOverride(
                        path=override,
                        source_url="https://example.test/v1.0.0/LICENSE",
                    )
                },
            )

        self.assertIn("Audited upstream license", notice)
        self.assertIn("audited repository override", notice)
        self.assertIn("https://example.test/v1.0.0/LICENSE", notice)

    def test_check_mode_rejects_notice_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "notice.txt"
            output.write_text("stale\n", encoding="utf-8")

            with self.assertRaisesRegex(
                generate_rust_licenses.LicenseNoticeError,
                "out of date",
            ):
                generate_rust_licenses.sync_notice(
                    output,
                    "current\n",
                    check=True,
                )

    def test_build_std_selects_reachable_vendor_and_special_local_packages(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = self._build_std_fixture(Path(temporary_directory))

            build_std = generate_rust_licenses.load_build_std_licenses(sysroot)

        self.assertEqual(
            [(package.name, package.version) for package in build_std.packages],
            [
                ("compiler_builtins", "0.1.160"),
                ("reachable", "1.2.3"),
                ("transitive", "2.0.0"),
            ],
        )
        self.assertEqual(
            build_std.toolchain,
            generate_rust_licenses.BUILD_STD_TOOLCHAIN,
        )
        self.assertEqual(build_std.roots, ("std", "panic_abort"))

    def test_build_std_notice_has_stable_provenance_and_all_license_texts(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            sysroot = self._build_std_fixture(root)
            build_std = generate_rust_licenses.load_build_std_licenses(sysroot)

            notice = generate_rust_licenses.render_notice(
                [],
                target="wasm32-unknown-unknown",
                build_std=build_std,
            )

            self.assertNotIn(str(root), notice)

        self.assertIn("nightly-2026-08-01", notice)
        self.assertIn("std, panic_abort", notice)
        self.assertIn("compiler-builtins license text", notice)
        self.assertIn("MIT license for reachable", notice)
        self.assertIn("MIT license for transitive", notice)
        self.assertIn("Rust standard library copyright and license text", notice)
        self.assertNotIn("unused 9.9.9", notice)

    def test_build_std_missing_canonical_standard_library_notice_fails_closed(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = self._build_std_fixture(Path(temporary_directory))
            (
                sysroot / "share" / "doc" / "rust" / "COPYRIGHT-library.html"
            ).unlink()

            with self.assertRaisesRegex(
                generate_rust_licenses.LicenseNoticeError,
                "COPYRIGHT-library.html",
            ):
                generate_rust_licenses.load_build_std_licenses(sysroot)

    def test_build_std_missing_vendor_license_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = self._build_std_fixture(Path(temporary_directory))
            license_path = (
                sysroot
                / "lib"
                / "rustlib"
                / "src"
                / "rust"
                / "library"
                / "vendor"
                / "transitive-2.0.0"
                / "LICENSE-MIT"
            )
            license_path.unlink()
            build_std = generate_rust_licenses.load_build_std_licenses(sysroot)

            with self.assertRaisesRegex(
                generate_rust_licenses.LicenseNoticeError,
                "transitive 2.0.0",
            ):
                generate_rust_licenses.render_notice(
                    [],
                    target="wasm32-unknown-unknown",
                    build_std=build_std,
                )


if __name__ == "__main__":
    unittest.main()
