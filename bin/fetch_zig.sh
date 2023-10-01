#!/bin/sh
ZIG_VERSION="0.11.0"

####

os_str=$(uname -s | tr '[:upper:]' '[:lower:]')
arch_str=$(uname -m | tr '[:upper:]' '[:lower:]')

if [ "$arch_str" = "arm64" ]; then
    arch="aarch64"
else
    arch=$arch_str
fi

if [ "$os_str" = "darwin" ]; then
    os="macos"
else
    os=$os_str
fi

zig_url=$(curl -s https://ziglang.org/download/index.json | jq --raw-output ".\"$ZIG_VERSION\".\"$arch-$os\".\"tarball\"")

if [ "$zig_url" = "nul" ]; then
    echo "Cannot auto-detect a Zig release for your combination of OS and CPU!"
    exit 1
fi

echo "Downloading Zig ($ZIG_VERSION) for: $arch-$os..."

wget --show-progress -O zig.tar.xz $zig_url