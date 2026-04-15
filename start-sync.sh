#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

# 首次运行时编译二进制
if [ ! -f "./target/release/cloudflare-ddns" ]; then
    echo "编译 cloudflare-ddns..."
    cargo build --release
fi

exec ./target/release/cloudflare-ddns "$@"
