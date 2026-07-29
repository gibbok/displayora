#!/usr/bin/env python3
"""Remove only repository-owned generated outputs."""

from __future__ import annotations

import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    targets = [ROOT / "app" / ".build", ROOT / "dist"]
    home = Path.home().resolve()
    for target in targets:
        resolved = target.resolve()
        if resolved in {Path("/"), home, ROOT.resolve()} or ROOT.resolve() not in resolved.parents:
            raise RuntimeError(f"Refusing unsafe clean target: {resolved}")
    for target in targets:
        if target.exists():
            shutil.rmtree(target)
            print(f"Removed {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
