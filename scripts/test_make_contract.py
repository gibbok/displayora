#!/usr/bin/env python3
"""Check that the fixed Make target contract remains present and safe."""

from __future__ import annotations

import re
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "doctor",
    "check-specs",
    "check-architecture",
    "check-review",
    "build",
    "test",
    "format",
    "run",
    "bundle",
    "install",
    "run-installed",
    "verify",
    "verify-feature",
    "clean",
}
RECIPE_MARKERS = {
    "doctor": "python3 scripts/doctor.py",
    "check-specs": "python3 scripts/check_specs.py",
    "check-architecture": "python3 scripts/check_architecture.py",
    "check-review": 'python3 scripts/check_review.py "$(SPEC)"',
    "build": "swift build $(PACKAGE_FLAGS) $(SWIFT_FLAGS)",
    "test": "swift test $(PACKAGE_FLAGS) $(SWIFT_FLAGS)",
    "format": "swift format lint --recursive --strict",
    "run": "swift run $(PACKAGE_FLAGS) $(SWIFT_FLAGS) Displayora",
    "bundle": "scripts/build-app.sh",
    "install": "scripts/install-app.sh",
    "run-installed": "open",
    "verify-feature": 'python3 scripts/verify_feature.py "$(FEATURE)"',
    "clean": "python3 scripts/clean.py",
}


def main() -> int:
    text = (ROOT / "Makefile").read_text()
    targets = set(re.findall(r"^([a-z][a-z-]+):", text, re.MULTILINE))
    missing = REQUIRED - targets
    if missing:
        raise SystemExit("Makefile is missing targets: " + ", ".join(sorted(missing)))
    for target, marker in RECIPE_MARKERS.items():
        recipe = extract_recipe(text, target)
        if marker not in recipe:
            raise SystemExit(f"Make target {target!r} no longer performs its fixed action.")
    test_recipe = extract_recipe(text, "test")
    for regression in [
        "python3 scripts/test_make_contract.py",
        "python3 scripts/test_manifest_selection.py",
    ]:
        if regression not in test_recipe:
            raise SystemExit(f"Make test no longer runs {regression}.")
    verify_recipe = extract_recipe(text, "verify")
    if "python3 scripts/test_transactions.py" not in verify_recipe:
        raise SystemExit("Make verify no longer runs transactional integration tests.")
    assert_dependencies(text, "install", ["bundle"])
    assert_dependencies(
        text,
        "verify",
        [
            "doctor",
            "check-specs",
            "format",
            "build",
            "test",
            "check-architecture",
            "bundle",
        ],
    )

    clean = (ROOT / "scripts" / "clean.py").read_text()
    if "Applications" in clean or "Displayora.app" in clean:
        raise SystemExit("clean must never address the installed application")

    assert_invalid_argument(["make", "-s", "check-review", "SPEC=x"], "Usage:")
    assert_invalid_argument(["make", "-s", "verify-feature"], "Usage:")

    environment = os.environ.copy()
    environment["DISPLAYORA_FEATURES"] = "x'; exit 23; #"
    dry_run = subprocess.run(
        ["make", "-n", "bundle"],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )
    if dry_run.returncode or "exit 23" in dry_run.stdout or "scripts/build-app.sh" not in dry_run.stdout:
        raise SystemExit("bundle recipe interpolates feature selection into shell syntax")

    print("Make target contract checks passed.")
    return 0


def extract_recipe(makefile: str, target: str) -> str:
    match = re.search(
        rf"^{re.escape(target)}:[^\n]*\n((?:\t[^\n]*\n)*)",
        makefile,
        re.MULTILINE,
    )
    return match.group(1) if match else ""


def assert_dependencies(makefile: str, target: str, expected: list[str]) -> None:
    match = re.search(rf"^{re.escape(target)}:([^\n]*)$", makefile, re.MULTILINE)
    actual = match.group(1).split() if match else []
    if actual != expected:
        raise SystemExit(
            f"Make target {target!r} dependencies are {actual!r}, expected {expected!r}."
        )


def assert_invalid_argument(arguments: list[str], expected: str) -> None:
    result = subprocess.run(arguments, cwd=ROOT, capture_output=True, text=True)
    output = result.stdout + result.stderr
    if result.returncode == 0 or expected not in output:
        raise SystemExit(f"{' '.join(arguments)} did not reject invalid arguments precisely")


if __name__ == "__main__":
    raise SystemExit(main())
