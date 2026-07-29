#!/usr/bin/env python3
"""Check the terminal tools required by the foundation workflow."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


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

    with tempfile.TemporaryDirectory(prefix="displayora-doctor-") as temporary:
        probe = Path(temporary) / "Probe.swift"
        probe.write_text("import Foundation\nimport XCTest\n")
        compile_check = subprocess.run(
            [
                "swiftc",
                "-typecheck",
                "-module-cache-path",
                str(Path(temporary) / "module-cache"),
                str(probe),
            ],
            capture_output=True,
            text=True,
        )
    if compile_check.returncode:
        diagnostic = compile_check.stderr.strip().splitlines()
        error_lines = [line for line in diagnostic if "error:" in line]
        detail = error_lines[0] if error_lines else "unknown compiler error"
        print(
            "The selected Swift compiler, macOS SDK, and XCTest installation "
            "cannot compile a package probe.",
            file=sys.stderr,
        )
        print(detail, file=sys.stderr)
        return 1

    print("Displayora doctor: all required terminal tools are available.")
    print(version.splitlines()[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
