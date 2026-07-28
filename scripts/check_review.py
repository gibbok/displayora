#!/usr/bin/env python3
"""Validate review evidence for one Displayora implementation."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def tracker_row(spec_id: str) -> tuple[str, str, str] | None:
    pattern = re.compile(
        rf"^\|\s*{re.escape(spec_id)}\s*\|\s*[^|]+\|\s*[^|]+\|\s*[^|]+\|"
        r"\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$"
    )
    for line in (ROOT / "SPEC_STATUS.md").read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            implementation, review = (value.strip() for value in match.groups())
            return spec_id, implementation, review
    return None


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"\d{2}", sys.argv[1]):
        print("usage: scripts/check_review.py NN", file=sys.stderr)
        return 2
    spec_id = sys.argv[1]
    row = tracker_row(spec_id)
    if row is None:
        print(f"review validation failed: no tracker row for {spec_id}", file=sys.stderr)
        return 1

    _, implementation, review = row
    if implementation != "Verified":
        if review == "Approved":
            print(
                f"review validation failed: {spec_id} is Approved but not Verified",
                file=sys.stderr,
            )
            return 1
        print(f"Review validation passed ({spec_id} is {implementation}; report not required).")
        return 0

    if review != "Approved":
        print(
            f"review validation failed: {spec_id} is Verified without Approved review",
            file=sys.stderr,
        )
        return 1

    reports = sorted((ROOT / "specs" / "reviews").glob(f"{spec_id}-*-review.md"))
    if len(reports) != 1:
        print(
            f"review validation failed: expected one report for {spec_id}, found {len(reports)}",
            file=sys.stderr,
        )
        return 1

    text = reports[0].read_text(encoding="utf-8")
    errors: list[str] = []
    required = (
        "## Round ",
        "### Blocking findings",
        "### Non-blocking findings",
        "### Automatic repairs and validation",
        "Acceptance criteria passing:",
        "Focused checks:",
        "Full regression checks:",
        "Standalone and omission checks:",
        "Tests or acceptance criteria weakened: No",
        "Blocking findings remaining: 0",
        "Final verdict: Approved",
    )
    for phrase in required:
        if phrase not in text:
            errors.append(f"missing {phrase!r}")
    if re.search(r"Blocking findings remaining:\s*[1-9]\d*", text):
        errors.append("unresolved blocking findings")
    if re.search(r"\b(?:TODO|TBD|FIXME)\b", text, re.IGNORECASE):
        errors.append("unresolved placeholder")

    if errors:
        print(f"review validation failed for {reports[0].name}:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Review validation passed ({reports[0].relative_to(ROOT)}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
