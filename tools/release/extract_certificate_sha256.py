from __future__ import annotations

import sys

from tools.release.release_config import (
    ReleaseConfigError,
    extract_single_certificate_sha256,
)


def main() -> int:
    try:
        fingerprint = extract_single_certificate_sha256(sys.stdin.read())
    except ReleaseConfigError as error:
        print(error, file=sys.stderr)
        return 1
    print(fingerprint)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
