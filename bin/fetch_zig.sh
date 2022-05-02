#!/bin/sh
ZIG_URL=$(curl -s https://ziglang.org/download/index.json | jq --raw-output ".\"0.10.0\".\"x86_64-linux\".\"tarball\"")
wget --show-progress -O zig.tar.xz $ZIG_URL