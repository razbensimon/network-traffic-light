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
key_source_args=()

if [[ ! -x "$sparkle_bin/generate_appcast" ]]; then
    echo "Sparkle tools are unavailable. Run 'swift package resolve' first." >&2
    exit 1
fi

if [[ -n "${SPARKLE_ED_KEY_FILE:-}" ]]; then
    key_source_args=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
fi

"$root/Scripts/build-app.sh"
mkdir -p "$release_dir"
rm -f "$archive"
ditto -c -k --keepParent "$root/build/NetworkTrafficLight.app" "$archive"

cp "$root/appcast.xml" "$release_dir/appcast.xml"
"$sparkle_bin/generate_appcast" \
    "${key_source_args[@]}" \
    --download-url-prefix "$download_url" \
    --maximum-deltas 0 \
    --maximum-versions 0 \
    --versions "$build" \
    -o "$release_dir/appcast.xml" \
    "$release_dir"
/usr/bin/python3 - "$release_dir/appcast.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
namespace = f"{{{sparkle}}}"
ET.register_namespace("sparkle", sparkle)

tree = ET.parse(path)
for item in tree.findall("./channel/item"):
    version = item.findtext(f"{namespace}shortVersionString")
    if not version:
        continue

    for deltas in item.findall(f"{namespace}deltas"):
        item.remove(deltas)

    for enclosure in item.findall("enclosure"):
        url = enclosure.get("url", "")
        marker = "/releases/download/"
        if marker not in url:
            continue
        asset = url.split(marker, 1)[1].split("/", 1)[-1]
        enclosure.set(
            "url",
            f"https://github.com/razbensimon/network-traffic-light"
            f"/releases/download/v{version}/{asset}",
        )

tree.write(path, encoding="utf-8", xml_declaration=True)
PY
cp "$release_dir/appcast.xml" "$root/appcast.xml"

echo "Prepared $archive"
echo "Updated appcast.xml; upload the archive to GitHub release v${version}, then commit and push appcast.xml."
