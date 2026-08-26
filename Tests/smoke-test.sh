#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir=${1:-"$root_dir/build/x86_64/Displayora.app"}
expected_arch=x86_64
plist="$app_dir/Contents/Info.plist"
executable="$app_dir/Contents/MacOS/Displayora"

test -d "$app_dir"
test -f "$plist"
test -x "$executable"

plutil -lint "$plist" >/dev/null
test "$(plutil -extract CFBundleIdentifier raw "$plist")" = "com.gibbok.displayora"
test "$(plutil -extract CFBundleExecutable raw "$plist")" = "Displayora"
test "$(plutil -extract CFBundlePackageType raw "$plist")" = "APPL"
test "$(plutil -extract LSMinimumSystemVersion raw "$plist")" = "13.0"
test "$(plutil -extract LSUIElement raw "$plist")" = "true"
codesign --verify --deep --strict "$app_dir"
lipo "$executable" -verify_arch "$expected_arch"
test "$(lipo -archs "$executable")" = "$expected_arch"

printf '%s\n' "Displayora $expected_arch build smoke test passed."
