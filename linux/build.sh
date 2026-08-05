#!/bin/bash
trap "exit" INT
set -eux

# Flutter version to build with; override with the FLUTTER_VERSION env var.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.6}"

cd "$(dirname "$0")/.."

# Switch the project to the pinned Flutter version via fvm.
# Set FLUTTER_CMD to bypass fvm and use a preinstalled Flutter instead.
if [ -z ${FLUTTER_CMD+x} ]; then
    fvm use "$FLUTTER_VERSION" --force
    FLUTTER_CMD="fvm flutter"
fi

# Clean the bundle output first: the tarball packages it wholesale, so
# leftover libs from removed plugins would get shipped.
rm -rf build/linux

$FLUTTER_CMD pub get --enforce-lockfile
# --no-pub: reuse the lockfile-enforced resolution above (build otherwise re-runs
# pub get without --enforce-lockfile).
$FLUTTER_CMD build linux --release -v --no-pub

arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    folder="x64"
elif [[ $arch == "aarch64" ]]; then
    folder="arm64"
fi

# Inject version number into version.json
tmp=$(mktemp)
chmod 644 "$tmp"
jq '.version = "2.0.0.0"' build/linux/$folder/release/bundle/data/flutter_assets/version.json > "$tmp" && mv "$tmp" build/linux/$folder/release/bundle/data/flutter_assets/version.json
chmod +x build/linux/$folder/release/bundle/bluebubbles

tar czvf bluebubbles-linux-"$arch".tar.gz -C build/linux/$folder/release/bundle .
sha256sum bluebubbles-linux-"$arch".tar.gz
