#!/usr/bin/env python3
"""Validate a universal, ad-hoc-signed Displayora application bundle."""

from __future__ import annotations

import plistlib
import subprocess
import sys
from pathlib import Path


EXPECTED_ARCHITECTURES = {"arm64", "x86_64"}


def run(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, check=False, capture_output=True, text=True)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: check_bundle.py /path/to/Displayora.app", file=sys.stderr)
        return 2

    app = Path(sys.argv[1]).resolve()
    executable = app / "Contents" / "MacOS" / "Displayora"
    info = app / "Contents" / "Info.plist"
    errors: list[str] = []

    if app.name != "Displayora.app" or not executable.is_file() or not info.is_file():
        print(f"{app} is not a complete Displayora.app bundle.", file=sys.stderr)
        return 1
    if not executable.stat().st_mode & 0o111:
        errors.append("bundle executable does not have an executable permission bit")
    executable_bytes = executable.read_bytes()
    if b"foundation-fixture" in executable_bytes:
        errors.append("bundle contains the compile-time-only foundation UI fixture")

    with info.open("rb") as handle:
        plist = plistlib.load(handle)
    expected = {
        "CFBundleIdentifier": "com.displayora.Displayora",
        "CFBundleExecutable": "Displayora",
        "CFBundleName": "Displayora",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
    }
    for key, value in expected.items():
        if plist.get(key) != value:
            errors.append(f"installed plist {key} is {plist.get(key)!r}, expected {value!r}")

    arch_result = run("lipo", "-archs", str(executable))
    architectures = set(arch_result.stdout.split()) if arch_result.returncode == 0 else set()
    if architectures != EXPECTED_ARCHITECTURES:
        errors.append(
            "bundle architectures are "
            + (", ".join(sorted(architectures)) or "unreadable")
            + "; expected arm64 and x86_64"
        )

    loads = run("otool", "-L", str(executable))
    if loads.returncode:
        errors.append("otool could not inspect the executable")
    else:
        for line in loads.stdout.splitlines()[1:]:
            load_path = line.strip().split(" ", 1)[0]
            if ".build" in load_path:
                errors.append(f"unresolved SwiftPM build load path: {load_path}")
            if load_path.startswith("/") and not load_path.startswith(("/usr/lib/", "/System/Library/")):
                errors.append(f"non-system absolute load path: {load_path}")

    signature = run("codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app))
    if signature.returncode:
        errors.append("bundle signature verification failed: " + signature.stderr.strip())
    signature_details = run("codesign", "-dv", "--verbose=4", str(app))
    if "Signature=adhoc" not in signature_details.stderr:
        errors.append("bundle signature is not ad-hoc")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated universal signed bundle: {app}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
