#!/usr/bin/env python3
"""Run an isolated platform or optional-feature verification scope."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLATFORM_SCOPES = {"foundation", "shell", "display-platform", "release"}
OPTIONAL_SCOPES = {
    "brightness",
    "contrast",
    "volume-and-mute",
    "resolution-selector",
    "keyboard-controls",
    "disable-and-reenable-display",
    "night-comfort",
}


def run(arguments: list[str], environment: dict[str, str]) -> None:
    subprocess.run(arguments, cwd=ROOT, env=environment, check=True)


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1]:
        print("Usage: make verify-feature FEATURE=<scope>", file=sys.stderr)
        return 2
    scope = sys.argv[1]
    if scope not in PLATFORM_SCOPES | OPTIONAL_SCOPES:
        print(f"Unknown verification scope '{scope}'.", file=sys.stderr)
        return 2
    if scope != "foundation":
        print(f"Verification scope '{scope}' is recognized but not yet implemented.", file=sys.stderr)
        return 2

    environment = os.environ.copy()
    environment["DISPLAYORA_FEATURES"] = ""
    scratch = ROOT / "app" / ".build" / "feature-foundation"
    flags = [
        "--package-path",
        "app",
        "--scratch-path",
        str(scratch),
        "-Xswiftc",
        "-warnings-as-errors",
        "-Xswiftc",
        "-strict-concurrency=complete",
    ]
    run(["swift", "build", *flags, "--product", "DisplayoraFeatureTestHost"], environment)
    for target in [
        "DisplayoraCoreTests",
        "DisplayoraUITests",
        "DisplayoraCompositionTests",
        "DisplayoraTests",
        "DisplayoraFeatureTestHostTests",
    ]:
        run(["swift", "test", *flags, "--filter", target], environment)

    bin_result = subprocess.run(
        ["swift", "build", *flags, "--show-bin-path"],
        cwd=ROOT,
        env=environment,
        check=True,
        capture_output=True,
        text=True,
    )
    host = Path(bin_result.stdout.strip()) / "DisplayoraFeatureTestHost"
    empty_result = subprocess.run(
        [str(host), "--expect-feature", "brightness"],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )
    if empty_result.returncode == 0 or "expected exactly one installed feature" not in empty_result.stderr:
        print("Empty composition host failure assertion did not behave as expected.", file=sys.stderr)
        return 1

    run(["python3", "scripts/check_architecture.py"], environment)
    print("Foundation feature scope verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
