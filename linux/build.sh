#!/bin/bash
trap "exit" INT
set -eux

cd "$(dirname "$0")/.."
flutter pub get
flutter build linux --release -v

arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    folder="x64"
elif [[ $arch == "aarch64" ]]; then
    folder="arm64"
fi

# Inject version number into version.json
tmp=$(mktemp)
chmod 644 "$tmp"
jq '.version = "1.12.101.0"' build/linux/$folder/release/bundle/data/flutter_assets/version.json > "$tmp" && mv "$tmp" build/linux/$folder/release/bundle/data/flutter_assets/version.json
chmod +x build/linux/$folder/release/bundle/bluebubbles

tar cvf bluebubbles-linux-"$arch".tar -C build/linux/$folder/release/bundle .
