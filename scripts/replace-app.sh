#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: replace-app.sh SOURCE_APP DESTINATION_APP VALIDATOR" >&2
    exit 64
fi

source_app=$1
destination_app=$2
validator=$3

if [[ ! -d "$source_app" || "$(basename "$source_app")" != "Displayora.app" ]]; then
    echo "Source must be a Displayora.app directory." >&2
    exit 65
fi
if [[ "$(basename "$destination_app")" != "Displayora.app" ]]; then
    echo "Destination must end in Displayora.app." >&2
    exit 65
fi
if [[ ! -x "$validator" ]]; then
    echo "Validator is not executable: $validator" >&2
    exit 65
fi

destination_parent=$(cd "$(dirname "$destination_app")" && pwd -P)
destination_app="$destination_parent/Displayora.app"
staging_root="$destination_parent/.displayora-staging.$$"
staging_app="$staging_root/Displayora.app"
backup_app="$destination_parent/.Displayora.app.backup"
moved_previous=0
installed_new=0

if [[ "$destination_parent" == "/" || "$destination_parent" == "$HOME" ]]; then
    echo "Refusing unsafe destination parent: $destination_parent" >&2
    exit 65
fi
if [[ -e "$staging_root" || -e "$backup_app" ]]; then
    echo "A Displayora staging or backup path already exists beside the destination." >&2
    exit 66
fi

restore_previous() {
    status=$?
    if [[ $status -ne 0 ]]; then
        if [[ $installed_new -eq 1 && -e "$destination_app" ]]; then
            rm -rf "$destination_app"
        fi
        if [[ $moved_previous -eq 1 && -e "$backup_app" ]]; then
            mv "$backup_app" "$destination_app"
        fi
    fi
    if [[ -e "$staging_root" ]]; then
        rm -rf "$staging_root"
    fi
    exit "$status"
}
trap restore_previous EXIT

mkdir "$staging_root"
cp -R "$source_app" "$staging_app"
"$validator" "$staging_app"

if [[ -e "$destination_app" ]]; then
    mv "$destination_app" "$backup_app"
    moved_previous=1
fi
mv "$staging_app" "$destination_app"
rmdir "$staging_root"
installed_new=1

if [[ "${DISPLAYORA_TEST_FAIL_AFTER_MOVE:-0}" == "1" ]]; then
    echo "Injected post-install validation failure." >&2
    false
fi

"$validator" "$destination_app"

if [[ $moved_previous -eq 1 ]]; then
    rm -rf "$backup_app"
fi
moved_previous=0
installed_new=0
trap - EXIT
