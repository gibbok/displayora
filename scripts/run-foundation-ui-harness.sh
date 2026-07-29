#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^(loading|populated|failed)$ ]]; then
    echo "usage: make run-ui-harness STATE=loading|populated|failed" >&2
    exit 64
fi

root=$(cd "$(dirname "$0")/.." && pwd -P)
DISPLAYORA_FEATURES='' DISPLAYORA_FOUNDATION_UI_HARNESS=1 \
    swift run --package-path "$root/app" \
    -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete \
    Displayora "$1"
