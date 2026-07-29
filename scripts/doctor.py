#!/usr/bin/env python3
"""Check the terminal tools required by the foundation workflow."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys


REQUIRED = ["swift", "python3", "make", "lipo", "otool", "plutil", "codesign"]


def main() -> int:
    missing = [tool for tool in REQUIRED if shutil.which(tool) is None]
    if missing:
        print(f"Missing required tools: {', '.join(missing)}", file=sys.stderr)
        return 1

    version = subprocess.run(
        ["swift", "--version"], check=True, capture_output=True, text=True
    ).stdout
    match = re.search(r"Swift version (\d+)", version)
    if not match or int(match.group(1)) != 6:
        print("Displayora requires a Swift 6 toolchain.", file=sys.stderr)
        return 1

    format_check = subprocess.run(
        ["swift", "format", "--version"], capture_output=True, text=True
    )
    if format_check.returncode:
        print("The selected Swift toolchain does not provide swift format.", file=sys.stderr)
        return 1

    print("Displayora doctor: all required terminal tools are available.")
    print(version.splitlines()[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
