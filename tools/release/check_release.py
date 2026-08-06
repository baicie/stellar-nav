from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from tools.release.release_config import (
    ANDROID_ABIS,
    ReleaseConfigError,
    load_release_config,
)


FIELDS = {
    "version": lambda config: config.version,
    "tag": lambda config: config.tag,
    "version_code": lambda config: str(config.version_code),
    "application_id": lambda config: config.application_id,
    "certificate_sha256": lambda config: config.certificate_sha256,
    "release_notes": lambda config: str(config.release_notes),
    "is_prerelease": lambda config: str(config.is_prerelease).lower(),
}


def parse_args(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Android release metadata.")
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--version", required=True)
    parser.add_argument("--field", choices=(*FIELDS, "split_version_code"))
    parser.add_argument("--abi", choices=ANDROID_ABIS)
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    options = parse_args(sys.argv[1:] if arguments is None else arguments)
    try:
        config = load_release_config(options.project_root, options.version)
    except (OSError, ReleaseConfigError) as error:
        print(error, file=sys.stderr)
        return 1

    if options.field == "split_version_code":
        if options.abi is None:
            print("--abi is required with --field split_version_code", file=sys.stderr)
            return 1
        print(config.split_version_code(options.abi))
    elif options.abi is not None:
        print("--abi is only valid with --field split_version_code", file=sys.stderr)
        return 1
    elif options.field:
        print(FIELDS[options.field](config))
    else:
        print(
            json.dumps(
                {
                    "version": config.version,
                    "tag": config.tag,
                    "versionCode": config.version_code,
                    "applicationId": config.application_id,
                    "certificateSha256": config.certificate_sha256,
                    "releaseNotes": str(config.release_notes),
                    "prerelease": config.is_prerelease,
                    "assets": config.asset_names,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
