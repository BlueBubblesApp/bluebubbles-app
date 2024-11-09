#!/bin/bash
trap "exit" INT
if [ -z ${FLUTTER_CMD+x} ]; then FLUTTER_CMD="flutter"; fi
set -eux

cd "$(dirname "$0")/.."

"$FLUTTER_CMD" pub get
"$FLUTTER_CMD" build linux --release -v

arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    folder="x64"
elif [[ $arch == "aarch64" ]]; then
    folder="arm64"
fi

# Inject version number into version.json
tmp=$(mktemp)
chmod 644 "$tmp"
jq '.version = "1.15.0.0"' build/linux/$folder/release/bundle/data/flutter_assets/version.json > "$tmp" && mv "$tmp" build/linux/$folder/release/bundle/data/flutter_assets/version.json
chmod +x build/linux/$folder/release/bundle/bluebubbles

tar cvf bluebubbles-linux-"$arch".tar -C build/linux/$folder/release/bundle .
sha256sum bluebubbles-linux-"$arch".tar
