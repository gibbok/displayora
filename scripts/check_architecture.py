#!/usr/bin/env python3
"""Check optional-feature boundaries without external dependencies."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
FEATURES = {
    "BrightnessFeature",
    "ContrastFeature",
    "VolumeFeature",
    "ResolutionFeature",
    "KeyboardControlsFeature",
    "DisplayStateFeature",
    "NightComfortFeature",
}


def main() -> int:
    package = APP / "Package.swift"
    if not package.exists():
        print("Architecture validation passed (application package not implemented yet).")
        return 0

    errors: list[str] = []
    package_text = package.read_text(encoding="utf-8")
    for feature in FEATURES:
        target_match = re.search(
            rf"\.target\s*\(\s*name:\s*\"{re.escape(feature)}\"(?P<body>.*?)\n\s*\)",
            package_text,
            flags=re.DOTALL,
        )
        if not target_match:
            continue
        body = target_match.group("body")
        siblings = sorted((FEATURES - {feature}) & set(re.findall(r'"(\w+Feature)"', body)))
        if siblings:
            errors.append(f"{feature} target depends on sibling(s): {', '.join(siblings)}")

    sources = APP / "Sources"
    if sources.exists():
        for feature in FEATURES:
            feature_root = sources / feature
            if not feature_root.exists():
                continue
            for path in feature_root.rglob("*.swift"):
                text = path.read_text(encoding="utf-8")
                for sibling in FEATURES - {feature}:
                    if re.search(rf"^\s*(?:@testable\s+)?import\s+{sibling}\s*$", text, re.MULTILINE):
                        errors.append(
                            f"{path.relative_to(ROOT)} imports sibling module {sibling}"
                        )

    project_files = list(APP.rglob("*.xcodeproj")) + list(APP.rglob("project.pbxproj"))
    if project_files:
        errors.append("terminal-only project must not contain an Xcode project")

    if errors:
        print("Architecture validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Architecture validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
