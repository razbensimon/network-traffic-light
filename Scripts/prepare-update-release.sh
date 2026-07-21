#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

sparkle_bin="$root/.build/artifacts/sparkle/Sparkle/bin"
release_dir="$root/release-artifacts"
plist="$root/Resources/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
archive_name="NetworkTrafficLight-${version}.zip"
archive="$release_dir/$archive_name"
download_url="https://github.com/razbensimon/network-traffic-light/releases/download/v${version}/"

if [[ ! -x "$sparkle_bin/generate_appcast" ]]; then
    echo "Sparkle tools are unavailable. Run 'swift package resolve' first." >&2
    exit 1
fi

"$root/Scripts/build-app.sh"
mkdir -p "$release_dir"
rm -f "$archive"
ditto -c -k --keepParent "$root/build/NetworkTrafficLight.app" "$archive"

cp "$root/appcast.xml" "$release_dir/appcast.xml"
"$sparkle_bin/generate_appcast" \
    --download-url-prefix "$download_url" \
    --maximum-versions 0 \
    --versions "$build" \
    -o "$release_dir/appcast.xml" \
    "$release_dir"
cp "$release_dir/appcast.xml" "$root/appcast.xml"

echo "Prepared $archive"
echo "Updated appcast.xml; upload the archive to GitHub release v${version}, then commit and push appcast.xml."
