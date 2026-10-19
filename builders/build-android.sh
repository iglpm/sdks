#!/usr/bin/env bash
# build-android.sh <target> [out_dir]
# Extracts Android NDK sysroot libraries and headers for a single architecture
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-aarch64-linux-android}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include"

NDK_VERSION="r27c"
NDK_ZIP="$WORK/ndk.zip"

case "$TARGET" in
    aarch64-linux-android)
        ARCH_SUBDIR="aarch64-linux-android"
        ;;
    armv7-linux-androideabi)
        ARCH_SUBDIR="arm-linux-androideabi"
        ;;
    x86_64-linux-android)
        ARCH_SUBDIR="x86_64-linux-android"
        ;;
    i686-linux-android)
        ARCH_SUBDIR="i686-linux-android"
        ;;
    *)
        log_err "Unknown Android target: $TARGET"
        ;;
esac

log "Fetching Android NDK $NDK_VERSION for $TARGET..."
fetch "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" "$NDK_ZIP"

log "Extracting NDK..."
apt_install unzip
unzip -q "$NDK_ZIP" -d "$WORK"
NDK_ROOT="$WORK/android-ndk-${NDK_VERSION}"

LLVM_SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# Copy target-specific usr/lib and common usr/include
if [ -d "$LLVM_SYSROOT/usr/include" ]; then
    cp -a "$LLVM_SYSROOT/usr/include/." "$SYSROOT/usr/include/"
fi
if [ -d "$LLVM_SYSROOT/usr/lib/$ARCH_SUBDIR" ]; then
    cp -a "$LLVM_SYSROOT/usr/lib/$ARCH_SUBDIR/." "$SYSROOT/usr/lib/"
fi

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"
