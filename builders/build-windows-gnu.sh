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
    aarch64-pc-windows-gnullvm)
        # Ubuntu does not package aarch64 MinGW libraries. Fetch llvm-mingw sysroot.
        log "Downloading llvm-mingw sysroot for ARM64 Windows..."
        LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-ubuntu-22.04-x86_64.tar.xz"
        fetch "$LLVM_MINGW_URL" "$WORK/llvm-mingw.tar.xz"
        tar -xf "$WORK/llvm-mingw.tar.xz" -C "$WORK"
        LLVM_ROOT="$(find "$WORK" -maxdepth 1 -type d -name "llvm-mingw*")"
        if [ -d "$LLVM_ROOT/aarch64-w64-mingw32" ]; then
            cp -a "$LLVM_ROOT/aarch64-w64-mingw32/include/." "$SYSROOT/usr/include/"
            cp -a "$LLVM_ROOT/aarch64-w64-mingw32/lib/." "$SYSROOT/usr/lib/"
        fi
        clean_sysroot "$SYSROOT"
        pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"
        exit 0
        ;;
    x86_64-pc-windows-gnullvm)
        MINGW_TRIPLE="x86_64-w64-mingw32"
        PACKAGES="mingw-w64-x86-64-dev g++-mingw-w64-x86-64"
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
