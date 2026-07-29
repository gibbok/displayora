#!/usr/bin/env python3
"""Validate the stable shape and traceability of numbered specifications."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_HEADINGS = [
    "## Metadata",
    "## Goal",
    "## Non-Goals",
    "## User Experience and States",
    "## Requirements",
    "## Interfaces and Data Flow",
    "## Failure and Recovery",
    "## Accessibility and Permissions",
    "## Platform Considerations",
    "## Standalone and Omission Behavior",
    "## Acceptance Criteria and Traceability",
    "## Verification",
]


def main() -> int:
    errors: list[str] = []
    specs = sorted((ROOT / "specs").glob("[0-9][0-9]-*.md"))
    if len(specs) != 11:
        errors.append(f"expected 11 numbered specifications, found {len(specs)}")

    for path in specs:
        text = path.read_text()
        for heading in REQUIRED_HEADINGS:
            if heading not in text:
                errors.append(f"{path.relative_to(ROOT)}: missing {heading}")
        requirements = set(re.findall(r"DORA-(\d{2}-\d{3})", text))
        traced = set(re.findall(r"`DORA-(\d{2}-\d{3})`", text.split("## Verification")[0]))
        if not requirements:
            errors.append(f"{path.relative_to(ROOT)}: no requirements found")
        if requirements - traced:
            errors.append(
                f"{path.relative_to(ROOT)}: untraced requirements "
                + ", ".join(sorted(requirements - traced))
            )
        if re.search(r"<(?:count|Approved or|Codex agent|different Codex)", text):
            errors.append(f"{path.relative_to(ROOT)}: unresolved placeholder")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Specification validation passed for {len(specs)} specifications.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
