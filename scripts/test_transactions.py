#!/usr/bin/env python3
"""Exercise installer success and rollback without touching the real installation."""

from __future__ import annotations

import os
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "dist" / "Displayora.app"
VALIDATOR = ROOT / "scripts" / "check_bundle.py"


def run(destination: Path, fail: bool = False) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["DISPLAYORA_INSTALL_DESTINATION"] = str(destination)
    if fail:
        environment["DISPLAYORA_TEST_FAIL_AFTER_MOVE"] = "1"
    return subprocess.run(
        [str(ROOT / "scripts" / "install-app.sh")],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )


def replace(destination: Path, fail: bool = False) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    if fail:
        environment["DISPLAYORA_TEST_FAIL_AFTER_MOVE"] = "1"
    return subprocess.run(
        [
            str(ROOT / "scripts" / "replace-app.sh"),
            str(SOURCE),
            str(destination),
            str(VALIDATOR),
        ],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )


def fingerprint(app: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in app.rglob("*") if item.is_file()):
        digest.update(str(path.relative_to(app)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def validate(app: Path) -> None:
    result = subprocess.run(
        [str(VALIDATOR), str(app)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise SystemExit(result.stderr)


def assert_installer_rollback(destination: Path) -> None:
    validate(destination)
    before = fingerprint(destination)
    failed = run(destination, fail=True)
    if failed.returncode == 0:
        raise SystemExit("Injected installer failure unexpectedly succeeded.")
    validate(destination)
    if fingerprint(destination) != before:
        raise SystemExit("Installer rollback did not restore the byte-identical prior app.")
    assert_no_transaction_debris(destination)


def assert_bundle_rollback(destination: Path) -> None:
    validate(destination)
    before = fingerprint(destination)
    environment = os.environ.copy()
    environment["DISPLAYORA_BUNDLE_OUTPUT"] = str(destination)
    environment["DISPLAYORA_FEATURES"] = ""
    environment["DISPLAYORA_FOUNDATION_UI_HARNESS"] = "1"
    environment["DISPLAYORA_TEST_FAIL_AFTER_MOVE"] = "1"
    failed = subprocess.run(
        [str(ROOT / "scripts" / "build-app.sh")],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
    )
    if failed.returncode == 0:
        raise SystemExit("Injected build-app replacement failure unexpectedly succeeded.")
    validate(destination)
    if fingerprint(destination) != before:
        raise SystemExit("Bundle rollback did not restore the byte-identical prior app.")
    assert_no_transaction_debris(destination)


def assert_no_transaction_debris(destination: Path) -> None:
    if (destination.parent / ".Displayora.app.backup").exists():
        raise SystemExit("Transaction left a backup after rollback.")
    if list(destination.parent.glob(".displayora-staging.*")):
        raise SystemExit("Transaction left a staging directory after rollback.")


def assert_non_executable_is_rejected(parent: Path) -> None:
    destination = parent / "NonExecutable" / "Displayora.app"
    destination.parent.mkdir()
    success = replace(destination)
    if success.returncode:
        raise SystemExit(success.stderr)
    executable = destination / "Contents" / "MacOS" / "Displayora"
    executable.chmod(0o644)
    result = subprocess.run(
        [str(VALIDATOR), str(destination)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0 or "executable permission bit" not in result.stderr:
        raise SystemExit("Bundle validator accepted a non-executable application.")


def main() -> int:
    if not SOURCE.is_dir():
        raise SystemExit("Run make bundle before installer integration tests.")

    with tempfile.TemporaryDirectory(prefix="displayora-install-") as temporary:
        destination = Path(temporary) / "Applications" / "Displayora.app"
        destination.parent.mkdir()
        success = run(destination)
        if success.returncode:
            raise SystemExit(success.stderr)

        assert_installer_rollback(destination)

        shutil.rmtree(destination)
        success_without_previous = run(destination)
        if success_without_previous.returncode:
            raise SystemExit(success_without_previous.stderr)

        bundle_destination = Path(temporary) / "BundleOutput" / "Displayora.app"
        bundle_destination.parent.mkdir()
        bundle_success = replace(bundle_destination)
        if bundle_success.returncode:
            raise SystemExit(bundle_success.stderr)
        assert_bundle_rollback(bundle_destination)
        assert_non_executable_is_rejected(Path(temporary))

    print("Bundle replacement and local installer success/rollback tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
