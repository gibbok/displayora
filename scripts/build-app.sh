#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
package="$root/app"
dist="$root/dist"
output_app="${DISPLAYORA_BUNDLE_OUTPUT:-$dist/Displayora.app}"
features="${DISPLAYORA_FEATURES-}"
intel_scratch="$package/.build/bundle-x86_64"
strict_flags=(-Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete)

mkdir -p "$dist"
output_parent=$(dirname "$output_app")
mkdir -p "$output_parent"
output_parent=$(cd "$output_parent" && pwd -P)
output_app="$output_parent/Displayora.app"

work=$(mktemp -d "$dist/.displayora-bundle.XXXXXX")
cleanup() {
    status=$?
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT

echo "Building Intel (x86_64) release binary"
DISPLAYORA_FOUNDATION_UI_HARNESS=0 DISPLAYORA_FEATURES="$features" \
    swift build --package-path "$package" \
    --configuration release --arch x86_64 --scratch-path "$intel_scratch" "${strict_flags[@]}"
intel_bin=$(DISPLAYORA_FOUNDATION_UI_HARNESS=0 DISPLAYORA_FEATURES="$features" \
    swift build --package-path "$package" \
    --configuration release --arch x86_64 --scratch-path "$intel_scratch" \
    "${strict_flags[@]}" --show-bin-path)

echo "x86_64 binary: $intel_bin/Displayora"

staged_app="$work/Displayora.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
cp "$package/Support/Info.plist" "$staged_app/Contents/Info.plist"
plutil -lint "$staged_app/Contents/Info.plist"
cp "$intel_bin/Displayora" "$staged_app/Contents/MacOS/Displayora"
chmod 755 "$staged_app/Contents/MacOS/Displayora"

architecture=$(file -b "$staged_app/Contents/MacOS/Displayora")
if [[ "$architecture" != *"x86_64"* ]]; then
    echo "Intel-only bundle has unexpected architecture: $architecture" >&2
    exit 1
fi
if otool -L "$staged_app/Contents/MacOS/Displayora" | tail -n +2 | awk '{print $1}' | grep -F ".build"; then
    echo "Bundle contains an unresolved SwiftPM build load path." >&2
    exit 1
fi

codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --deep --strict --verbose=2 "$staged_app"
"$root/scripts/check_bundle.py" "$staged_app"
"$root/scripts/replace-app.sh" "$staged_app" "$output_app" "$root/scripts/check_bundle.py"

trap - EXIT
rm -rf "$work"
echo "Created $output_app"
