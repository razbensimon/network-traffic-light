#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bin_dir="$(swift build -c release --show-bin-path)"
app="$root/build/NetworkTrafficLight.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/NetworkTrafficLight" "$app/Contents/MacOS/NetworkTrafficLight"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
echo "Built $app"
