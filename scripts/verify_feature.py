#!/usr/bin/env python3
"""Build and test one optional feature and its isolated test host."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
TARGETS = {
    "brightness": "BrightnessFeature",
    "contrast": "ContrastFeature",
    "volume-and-mute": "VolumeFeature",
    "resolution-selector": "ResolutionFeature",
    "keyboard-controls": "KeyboardControlsFeature",
    "disable-and-reenable-display": "DisplayStateFeature",
    "night-comfort": "NightComfortFeature",
}


def run(*arguments: str) -> None:
    subprocess.run(arguments, cwd=ROOT, check=True)


def main() -> int:
    feature = os.environ.get("FEATURE", "")
    if feature not in TARGETS:
        choices = ", ".join(sorted(TARGETS))
        print(f"FEATURE must be one of: {choices}", file=sys.stderr)
        return 2
    if not (APP / "Package.swift").exists():
        print("app/Package.swift has not been implemented", file=sys.stderr)
        return 1

    target = TARGETS[feature]
    flags = (
        "--package-path",
        str(APP),
        "-Xswiftc",
        "-warnings-as-errors",
        "-Xswiftc",
        "-strict-concurrency=complete",
    )
    run("swift", "build", "--target", target, *flags)
    run("swift", "test", "--filter", f"{target}Tests", *flags)
    run("swift", "test", "--filter", f"FeatureTestHostTests/{target}", *flags)
    print(f"Feature verification passed: {feature} ({target}).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from error
