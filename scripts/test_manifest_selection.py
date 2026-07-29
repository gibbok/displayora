#!/usr/bin/env python3
"""Exercise deterministic and precise DISPLAYORA_FEATURES manifest failures."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_COMMAND = [
    "swift",
    "package",
    "--package-path",
    "app",
    "--scratch-path",
    "app/.build/manifest-selection-tests",
    "describe",
]
CASES = {
    "unknown": "Unknown DISPLAYORA_FEATURES token 'unknown'",
    "brightness,brightness": "duplicate token 'brightness'",
    " brightness": "whitespace in token ' brightness'",
    "brightness,": "empty element",
    "brightness": "recognized but not yet implemented",
}


def evaluate(selection: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["DISPLAYORA_FEATURES"] = selection
    return subprocess.run(
        BASE_COMMAND,
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )


def main() -> int:
    empty = evaluate("")
    if empty.returncode:
        raise SystemExit("Explicitly empty feature selection must succeed:\n" + empty.stderr)

    for selection, expected in CASES.items():
        result = evaluate(selection)
        output = result.stdout + result.stderr
        if result.returncode == 0:
            raise SystemExit(f"Invalid feature selection {selection!r} unexpectedly succeeded.")
        if expected not in output:
            raise SystemExit(
                f"Feature selection {selection!r} did not report {expected!r}.\n{output}"
            )

    print("Manifest feature-selection checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
