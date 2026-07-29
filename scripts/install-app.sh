#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
source_app="${DISPLAYORA_INSTALL_SOURCE:-$root/dist/Displayora.app}"
home_path=$(cd "$HOME" && pwd -P)
destination="${DISPLAYORA_INSTALL_DESTINATION:-$home_path/Applications/Displayora.app}"

if [[ "$destination" != /* || "$(basename "$destination")" != "Displayora.app" ]]; then
    echo "Install destination must be an absolute path ending in Displayora.app." >&2
    exit 65
fi

destination_parent=$(dirname "$destination")
if [[ -z "${DISPLAYORA_INSTALL_DESTINATION:-}" ]]; then
    expected_parent="$home_path/Applications"
    if [[ "$destination_parent" != "$expected_parent" ]]; then
        echo "User Applications destination changed unexpectedly: $destination_parent" >&2
        exit 65
    fi
    mkdir -p "$expected_parent"
elif [[ ! -d "$destination_parent" ]]; then
    echo "Custom install destination parent must already exist: $destination_parent" >&2
    exit 65
fi

resolved_parent=$(cd "$destination_parent" && pwd -P)
if [[ -z "${DISPLAYORA_INSTALL_DESTINATION:-}" ]]; then
    if [[ "$resolved_parent" != "$expected_parent" ]]; then
        echo "Resolved user Applications path is unsafe: $resolved_parent" >&2
        exit 65
    fi
fi
if [[ "$resolved_parent" == "/" || "$resolved_parent" == "$home_path" ]]; then
    echo "Refusing unsafe install destination: $resolved_parent" >&2
    exit 65
fi

"$root/scripts/check_bundle.py" "$source_app"
"$root/scripts/replace-app.sh" \
    "$source_app" "$resolved_parent/Displayora.app" "$root/scripts/check_bundle.py"
"$root/scripts/check_bundle.py" "$resolved_parent/Displayora.app"
echo "Installed Displayora at $resolved_parent/Displayora.app"
