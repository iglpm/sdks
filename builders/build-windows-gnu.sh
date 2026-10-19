#!/usr/bin/env bash
# build-windows-gnu.sh <target> [out_dir]
# Packages MinGW-w64 CRT and import libraries for Windows GNU targets
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-x86_64-pc-windows-gnu}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include"

case "$TARGET" in
    x86_64-pc-windows-gnu)
        MINGW_TRIPLE="x86_64-w64-mingw32"
        PACKAGES="mingw-w64-x86-64-dev g++-mingw-w64-x86-64"
        ;;
    i686-pc-windows-gnu)
        MINGW_TRIPLE="i686-w64-mingw32"
        PACKAGES="mingw-w64-i686-dev g++-mingw-w64-i686"
        ;;
    x86_64-pc-windows-gnullvm|aarch64-pc-windows-gnullvm)
        # LLVM MinGW targets use standard MinGW-w64 headers and CRT libraries
        if [ "$TARGET" = "aarch64-pc-windows-gnullvm" ]; then
            MINGW_TRIPLE="aarch64-w64-mingw32"
            PACKAGES="mingw-w64-common"
        else
            MINGW_TRIPLE="x86_64-w64-mingw32"
            PACKAGES="mingw-w64-x86-64-dev g++-mingw-w64-x86-64"
        fi
        ;;
    *)
        log_err "Unknown Windows GNU target: $TARGET"
        ;;
esac

log "Packaging Windows MinGW SDK for $TARGET ($MINGW_TRIPLE)..."

apt_install $PACKAGES

if [ -d "/usr/$MINGW_TRIPLE" ]; then
    cp -a /usr/"$MINGW_TRIPLE"/include/. "$SYSROOT/usr/include/" 2>/dev/null || true
    cp -a /usr/"$MINGW_TRIPLE"/lib/. "$SYSROOT/usr/lib/" 2>/dev/null || true
fi

# Copy POSIX threads runtime if present
for gcc_dir in /usr/lib/gcc/"$MINGW_TRIPLE"/*-posix; do
    if [ -d "$gcc_dir" ]; then
        cp -a "$gcc_dir"/*.a "$SYSROOT/usr/lib/" 2>/dev/null || true
        cp -a "$gcc_dir"/*.o "$SYSROOT/usr/lib/" 2>/dev/null || true
    fi
done

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"
