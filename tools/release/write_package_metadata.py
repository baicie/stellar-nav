from __future__ import annotations

import argparse
import sys
from dataclasses import replace
from pathlib import Path

from tools.release.release_config import (
    ANDROID_ABIS,
    ReleaseConfigError,
    load_release_config,
    normalize_certificate_sha256,
    render_release_metadata,
)


def parse_args(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write Android package metadata.")
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--version", required=True)
    parser.add_argument("--certificate", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allow-test-certificate", action="store_true")
    for abi in ANDROID_ABIS:
        parser.add_argument(f"--{abi}", type=Path, required=True)
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    options = parse_args(sys.argv[1:] if arguments is None else arguments)
    try:
        config = load_release_config(options.project_root, options.version)
        certificate = normalize_certificate_sha256(options.certificate)
        if certificate != config.certificate_sha256 and not options.allow_test_certificate:
            raise ReleaseConfigError(
                "Packaged certificate does not match the release manifest."
            )
        if options.allow_test_certificate:
            config = replace(config, certificate_sha256=certificate)
        artifacts = {
            abi: getattr(options, abi.replace("-", "_")) for abi in ANDROID_ABIS
        }
        metadata = render_release_metadata(config, artifacts)
        options.output.parent.mkdir(parents=True, exist_ok=True)
        options.output.write_text(metadata, encoding="utf-8")
    except (OSError, ReleaseConfigError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
