#!/bin/bash
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

tar cvf bluebubbles-linux-"$arch".tar -C build/linux/$folder/release/bundle .
