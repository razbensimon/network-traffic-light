#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app="$root/build/NetworkTrafficLight.app"
sparkle_framework="$root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
rm -rf "$app"
mkdir -p "$app/Contents/Frameworks" "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/NetworkTrafficLight" "$app/Contents/MacOS/NetworkTrafficLight"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp -R "$sparkle_framework" "$app/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/NetworkTrafficLight"
codesign --force --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"
echo "Built $app"
