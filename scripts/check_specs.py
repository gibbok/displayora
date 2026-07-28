#!/usr/bin/env python3
"""Validate Displayora's tracker and numbered specification contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACKER = ROOT / "SPEC_STATUS.md"
SPECS = ROOT / "specs"

EXPECTED = {
    "01": ("Project Foundation", (), "project-foundation"),
    "02": ("Menu-Bar Shell and Onboarding", ("01",), "menu-bar-shell-and-onboarding"),
    "03": (
        "Display Platform and Capabilities",
        ("01", "02"),
        "display-platform-and-capabilities",
    ),
    "04": ("Brightness", ("01", "02", "03"), "brightness"),
    "05": ("Contrast", ("01", "02", "03"), "contrast"),
    "06": ("Volume and Mute", ("01", "02", "03"), "volume-and-mute"),
    "07": ("Resolution Selector", ("01", "02", "03"), "resolution-selector"),
    "08": ("Keyboard Controls", ("01", "02", "03"), "keyboard-controls"),
    "09": (
        "Disable and Re-enable Display",
        ("01", "02", "03"),
        "disable-and-reenable-display",
    ),
    "10": ("Night Comfort", ("01", "02", "03"), "night-comfort"),
    "11": (
        "Direct Distribution and Release",
        ("01", "02", "03"),
        "direct-distribution-and-release",
    ),
}

SPEC_STATES = {"Planned", "Drafting", "Ready", "Blocked"}
IMPLEMENTATION_STATES = {
    "Not started",
    "In progress",
    "Verified",
    "Deferred",
    "Omitted",
    "Blocked",
}
REVIEW_STATES = {"Not reviewed", "Reviewing", "Changes requested", "Approved"}

REQUIRED_HEADINGS = (
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
    "## Code Quality and Automatic Review",
    "## Author Self-Review",
    "### Pass 1",
    "### Pass 2",
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def parse_tracker(errors: list[str]) -> dict[str, tuple[str, tuple[str, ...], str, str, str]]:
    if not TRACKER.is_file():
        fail(errors, "missing SPEC_STATUS.md")
        return {}

    rows: dict[str, tuple[str, tuple[str, ...], str, str, str]] = {}
    for line in TRACKER.read_text(encoding="utf-8").splitlines():
        match = re.match(
            r"^\|\s*(\d{2})\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
            r"\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$",
            line,
        )
        if not match:
            continue
        spec_id, name, deps_text, spec_state, implementation, review = (
            part.strip() for part in match.groups()
        )
        deps = () if deps_text == "—" else tuple(re.findall(r"\d{2}", deps_text))
        if spec_id in rows:
            fail(errors, f"duplicate tracker row {spec_id}")
        rows[spec_id] = (name, deps, spec_state, implementation, review)

    for spec_id, (name, deps, _) in EXPECTED.items():
        if spec_id not in rows:
            fail(errors, f"missing tracker row {spec_id}")
            continue
        actual_name, actual_deps, spec_state, implementation, review = rows[spec_id]
        if actual_name != name:
            fail(errors, f"tracker {spec_id}: expected name {name!r}, got {actual_name!r}")
        if actual_deps != deps:
            fail(
                errors,
                f"tracker {spec_id}: expected dependencies {deps or 'none'}, "
                f"got {actual_deps or 'none'}",
            )
        if spec_state not in SPEC_STATES:
            fail(errors, f"tracker {spec_id}: invalid specification state {spec_state!r}")
        if implementation not in IMPLEMENTATION_STATES:
            fail(errors, f"tracker {spec_id}: invalid implementation state {implementation!r}")
        if review not in REVIEW_STATES:
            fail(errors, f"tracker {spec_id}: invalid code-review state {review!r}")
        if implementation == "Verified" and review != "Approved":
            fail(errors, f"tracker {spec_id}: Verified requires code review Approved")
        if review == "Approved" and implementation != "Verified":
            fail(errors, f"tracker {spec_id}: Approved review requires implementation Verified")

    extra = sorted(set(rows) - set(EXPECTED))
    if extra:
        fail(errors, f"unexpected tracker rows: {', '.join(extra)}")
    return rows


def validate_ready_spec(
    errors: list[str],
    spec_id: str,
    slug: str,
    dependencies: tuple[str, ...],
) -> None:
    path = SPECS / f"{spec_id}-{slug}.md"
    if not path.is_file():
        fail(errors, f"{spec_id}: Ready specification is missing {path.relative_to(ROOT)}")
        return

    text = path.read_text(encoding="utf-8")
    for heading in REQUIRED_HEADINGS:
        if heading not in text:
            fail(errors, f"{path.name}: missing heading beginning {heading!r}")

    if "```mermaid" not in text:
        fail(errors, f"{path.name}: missing Mermaid diagram")
    if not re.search(rf"\|\s*ID\s*\|\s*`?{spec_id}`?\s*\|", text):
        fail(errors, f"{path.name}: metadata does not identify {spec_id}")
    if not re.search(r"\|\s*Specification status\s*\|\s*Ready\s*\|", text):
        fail(errors, f"{path.name}: metadata specification status is not Ready")

    requirement_ids = set(re.findall(rf"DORA-{spec_id}-\d{{3}}", text))
    if len(requirement_ids) < 6:
        fail(errors, f"{path.name}: expected at least 6 stable requirement IDs")
    criteria_ids = set(re.findall(rf"AC-{spec_id}-\d{{2}}", text))
    test_ids = set(re.findall(rf"(?:TEST|MANUAL)-{spec_id}-\d{{2}}", text))
    if len(criteria_ids) < 4:
        fail(errors, f"{path.name}: expected at least 4 acceptance criteria")
    if len(test_ids) < len(criteria_ids):
        fail(errors, f"{path.name}: every acceptance criterion needs a test identifier")
    for requirement_id in requirement_ids:
        if text.count(requirement_id) < 2:
            fail(errors, f"{path.name}: {requirement_id} lacks acceptance traceability")

    required_phrases = (
        "Given",
        "When",
        "Then",
        "make verify-feature FEATURE=",
        "make check-architecture",
        "git diff --check",
        "Intel",
        "Apple Silicon",
        "Accessibility",
        "Codex",
        "automatically",
        "Blocking",
        "Approved",
        "Verified",
        "sibling",
        "omitted",
    )
    for phrase in required_phrases:
        if phrase not in text:
            fail(errors, f"{path.name}: missing required contract phrase {phrase!r}")

    forbidden = (
        r"\bTODO\b",
        r"\bTBD\b",
        r"\bFIXME\b",
        r"\bopen question\b",
        r"\bdecide later\b",
    )
    for pattern in forbidden:
        if re.search(pattern, text, flags=re.IGNORECASE):
            fail(errors, f"{path.name}: unresolved placeholder matching {pattern!r}")

    if spec_id in {"04", "05", "06", "07", "08", "09", "10"}:
        declared = re.search(r"\|\s*Dependencies\s*\|\s*([^|]+)\|", text)
        if not declared:
            fail(errors, f"{path.name}: missing dependency metadata")
        elif any(
            re.search(rf"\b{sibling}\b", declared.group(1))
            for sibling in ("04", "05", "06", "07", "08", "09", "10")
        ):
            fail(errors, f"{path.name}: optional feature declares sibling dependency")
        if "Optional standalone" not in text:
            fail(errors, f"{path.name}: optional classification is not explicit")

    for dependency in dependencies:
        if dependency not in EXPECTED:
            fail(errors, f"{path.name}: unknown dependency {dependency}")


def main() -> int:
    errors: list[str] = []
    rows = parse_tracker(errors)

    for spec_id, (_, expected_deps, slug) in EXPECTED.items():
        row = rows.get(spec_id)
        if not row:
            continue
        _, _, spec_state, _, _ = row
        if spec_state in {"Drafting", "Ready"}:
            path = SPECS / f"{spec_id}-{slug}.md"
            if not path.is_file():
                fail(errors, f"{spec_id}: {spec_state} specification file is missing")
        if spec_state == "Ready":
            for dependency in expected_deps:
                dependency_row = rows.get(dependency)
                if dependency_row and dependency_row[2] != "Ready":
                    fail(
                        errors,
                        f"{spec_id}: Ready while dependency {dependency} is "
                        f"{dependency_row[2]}",
                    )
            validate_ready_spec(errors, spec_id, slug, expected_deps)

    numbered = {
        path.name
        for path in SPECS.glob("[0-9][0-9]-*.md")
        if path.is_file()
    }
    expected_names = {
        f"{spec_id}-{slug}.md" for spec_id, (_, _, slug) in EXPECTED.items()
    }
    unexpected = sorted(numbered - expected_names)
    if unexpected:
        fail(errors, f"unexpected numbered specification files: {', '.join(unexpected)}")

    if errors:
        print("Specification validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    ready = sum(1 for row in rows.values() if row[2] == "Ready")
    print(f"Specification validation passed ({ready}/11 Ready).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
