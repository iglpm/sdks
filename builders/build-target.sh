#!/usr/bin/env bash
# build-target.sh <target> [out_dir]
# Router script to invoke the appropriate builder for any target supported by hyprcross
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-}"
OUT_DIR="${2:-dist}"

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target-triple> [out_dir]" >&2
    exit 1
fi

case "$TARGET" in
    *-unknown-linux-gnu|*-unknown-linux-gnueabi|*-unknown-linux-gnueabihf)
        "$DIR/build-linux-gnu.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-unknown-linux-musl|*-unknown-linux-musleabi|*-unknown-linux-musleabihf)
        "$DIR/build-linux-musl.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-pc-windows-gnu|*-pc-windows-gnullvm)
        "$DIR/build-windows-gnu.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-pc-windows-msvc)
        "$DIR/build-windows-msvc.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-linux-android|*-linux-androideabi)
        "$DIR/build-android.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-unknown-freebsd)
        "$DIR/build-freebsd.sh" "$TARGET" "$OUT_DIR"
        ;;
    *-apple-darwin)
        log "macOS SDK ($TARGET) is packaged from official Apple Command Line Tools / Xcode."
        log "See scripts/macos-sdk.sh for extraction instructions."
        ;;
    wasm32-*|thumbv*|riscv32imc-*)
        log "$TARGET is a self-contained target that links without an external C SDK."
        ;;
    *)
        log_err "No automated SDK builder found for target: $TARGET"
        ;;
esac
