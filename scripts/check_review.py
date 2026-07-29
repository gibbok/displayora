#!/usr/bin/env python3
"""Validate durable approval evidence for one specification."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"\d{2}", sys.argv[1] or ""):
        print("Usage: make check-review SPEC=NN", file=sys.stderr)
        return 2

    spec = sys.argv[1]
    reports = list((ROOT / "specs" / "reviews").glob(f"{spec}-*-review.md"))
    if len(reports) != 1:
        print(f"Expected one durable review report for Specification {spec}.", file=sys.stderr)
        return 1

    text = reports[0].read_text()
    required = [
        f"Specification: `{spec}`",
        "Tests or acceptance criteria weakened: No",
        "Blocking findings remaining: 0",
        "Final verdict: Approved",
    ]
    missing = [line for line in required if line not in text]
    if missing:
        print("Review approval is incomplete: " + "; ".join(missing), file=sys.stderr)
        return 1

    tracker = (ROOT / "specs" / "SPEC_STATUS.md").read_text()
    row = next((line for line in tracker.splitlines() if line.startswith(f"| {spec} |")), "")
    if "| Verified | Approved |" not in row:
        print(
            f"Specification {spec} tracker row is not implementation Verified / review Approved.",
            file=sys.stderr,
        )
        return 1

    print(f"Specification {spec} review approval is complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
