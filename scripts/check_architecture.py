#!/usr/bin/env python3
"""Dependency, isolation, bundle metadata, and forbidden-artifact checks."""

from __future__ import annotations

import json
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"


def main() -> int:
    errors: list[str] = []
    manifest = (APP / "Package.swift").read_text()

    required_targets = [
        "DisplayoraCore",
        "DisplayoraUI",
        "DisplayoraComposition",
        "Displayora",
        "DisplayoraFeatureTestHost",
        "DisplayoraTestSupport",
        "DisplayoraCoreTests",
        "DisplayoraUITests",
        "DisplayoraCompositionTests",
        "DisplayoraTests",
        "DisplayoraFeatureTestHostTests",
    ]
    for target in required_targets:
        if f'name: "{target}"' not in manifest:
            errors.append(f"Package.swift is missing target {target}")
    for required in [
        "// swift-tools-version: 6.0",
        "platforms: [.macOS(.v13)]",
        "swiftLanguageModes: [.v6]",
        "-warnings-as-errors",
        "-strict-concurrency=complete",
    ]:
        if required not in manifest:
            errors.append(f"Package.swift is missing {required}")
    package_declarations = re.findall(
        r'\.package\s*\(\s*url:\s*"([^"]+)"\s*,\s*exact:\s*"([^"]+)"\s*\)',
        manifest,
    )
    allowed_packages = [
        ("https://github.com/swiftlang/swift-testing.git", "6.2.4")
    ]
    package_call_count = len(re.findall(r"\.package\s*\(", manifest))
    if (
        package_declarations != allowed_packages
        or package_call_count != len(allowed_packages)
    ):
        errors.append(
            "Package.swift may declare only swift-testing 6.2.4 as a test dependency"
        )

    dump_environment = os.environ.copy()
    dump_environment.setdefault(
        "CLANG_MODULE_CACHE_PATH", "/tmp/displayora-architecture-clang-cache"
    )
    dump_environment.setdefault(
        "SWIFTPM_MODULECACHE_OVERRIDE",
        "/tmp/displayora-architecture-swiftpm-cache",
    )
    dump_result = subprocess.run(
        [
            "swift",
            "package",
            "--disable-sandbox",
            "--package-path",
            "app",
            "dump-package",
        ],
        cwd=ROOT,
        env=dump_environment,
        capture_output=True,
        text=True,
    )
    if dump_result.returncode:
        errors.append("swift package dump-package failed: " + dump_result.stderr.strip())
    else:
        package_graph = json.loads(dump_result.stdout)
        actual_dependencies = {
            target["name"]: {
                dependency_name(dependency)
                for dependency in target.get("dependencies", [])
            }
            for target in package_graph["targets"]
        }
        expected_dependencies = {
            "DisplayoraCore": set(),
            "DisplayoraUI": {"DisplayoraCore"},
            "DisplayoraComposition": {"DisplayoraUI"},
            "Displayora": {"DisplayoraComposition", "DisplayoraUI"},
            "DisplayoraFeatureTestHost": {"DisplayoraComposition", "DisplayoraUI"},
            "DisplayoraTestSupport": {"Testing"},
            "DisplayoraCoreTests": {"DisplayoraCore", "DisplayoraTestSupport"},
            "DisplayoraUITests": {
                "DisplayoraCore",
                "DisplayoraTestSupport",
                "DisplayoraUI",
            },
            "DisplayoraCompositionTests": {
                "DisplayoraComposition",
                "DisplayoraCore",
                "DisplayoraTestSupport",
                "DisplayoraUI",
            },
            "DisplayoraTests": {
                "Displayora",
                "DisplayoraCore",
                "DisplayoraTestSupport",
                "DisplayoraUI",
            },
            "DisplayoraFeatureTestHostTests": {
                "DisplayoraCore",
                "DisplayoraFeatureTestHost",
                "DisplayoraTestSupport",
                "DisplayoraUI",
            },
        }
        for target, expected_edges in expected_dependencies.items():
            actual_edges = actual_dependencies.get(target)
            if actual_edges != expected_edges:
                errors.append(
                    f"{target} dependencies are {sorted(actual_edges or set())}; "
                    f"expected {sorted(expected_edges)}"
                )

    imports: dict[str, set[str]] = {}
    for source_dir in (APP / "Sources").iterdir():
        if not source_dir.is_dir():
            continue
        module_imports: set[str] = set()
        for source in source_dir.glob("*.swift"):
            module_imports.update(re.findall(r"^import\s+(\w+)", source.read_text(), re.MULTILINE))
        imports[source_dir.name] = module_imports

    forbidden_imports = {
        "DisplayoraCore": {"DisplayoraUI", "DisplayoraComposition"},
        "DisplayoraUI": {"DisplayoraComposition"},
    }
    for module, forbidden in forbidden_imports.items():
        found = imports.get(module, set()) & forbidden
        if found:
            errors.append(f"{module} imports forbidden modules: {', '.join(sorted(found))}")

    feature_names = {
        "BrightnessFeature",
        "ContrastFeature",
        "VolumeFeature",
        "ResolutionFeature",
        "KeyboardControlsFeature",
        "DisplayStateFeature",
        "NightComfortFeature",
    }
    for module, module_imports in imports.items():
        if module != "DisplayoraComposition" and module_imports & feature_names:
            errors.append(f"{module} imports an optional feature outside composition")

    source_files = list(repository_files())
    forbidden_files = [
        path
        for path in source_files
        if path.suffix == ".xcodeproj" or path.name == "project.pbxproj"
    ]
    if forbidden_files:
        errors.append("Xcode project artifacts are forbidden")
    for path in [ROOT / "Makefile", *sorted((ROOT / "scripts").glob("*"))]:
        if path == Path(__file__).resolve():
            continue
        if path.is_file() and "xcodebuild" in path.read_text(errors="ignore"):
            errors.append(f"{path.relative_to(ROOT)} invokes forbidden xcodebuild")

    with (APP / "Support" / "Info.plist").open("rb") as handle:
        plist = plistlib.load(handle)
    expected = {
        "CFBundleIdentifier": "com.displayora.Displayora",
        "CFBundleExecutable": "Displayora",
        "CFBundleName": "Displayora",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
    }
    for key, value in expected.items():
        if plist.get(key) != value:
            errors.append(f"Info.plist {key} must be {value!r}")
    permission_keys = [key for key in plist if key.startswith("NS") and key.endswith("UsageDescription")]
    if permission_keys:
        errors.append("Foundation Info.plist must not contain permission usage descriptions")
    if any(path.suffix == ".entitlements" and APP in path.parents for path in source_files):
        errors.append("Foundation must not include entitlement files")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Architecture and isolation checks passed.")
    return 0


def dependency_name(dependency: dict[str, object]) -> str:
    for kind in ("byName", "target", "product"):
        if kind not in dependency:
            continue
        value = dependency[kind]
        if isinstance(value, list):
            return str(value[0])
        return str(value)
    raise ValueError(f"Unknown SwiftPM dependency shape: {dependency!r}")


def repository_files():
    generated_directories = {".git", ".build", "dist"}
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if generated_directories.intersection(relative.parts):
            continue
        yield path


if __name__ == "__main__":
    raise SystemExit(main())
