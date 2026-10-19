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

# Copy libunwind and compiler builtins from Clang runtime
CLANG_LIB_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/lib/clang"
for clang_ver in "$CLANG_LIB_DIR"/*; do
    if [ -d "$clang_ver/lib/linux" ]; then
        case "$TARGET" in
            aarch64-linux-android)
                [ -f "$clang_ver/lib/linux/aarch64/libunwind.a" ] && cp -a "$clang_ver/lib/linux/aarch64/libunwind.a" "$SYSROOT/usr/lib/" || true
                [ -f "$clang_ver/lib/linux/libclang_rt.builtins-aarch64-android.a" ] && cp -a "$clang_ver/lib/linux/libclang_rt.builtins-aarch64-android.a" "$SYSROOT/usr/lib/" || true
                ;;
            armv7-linux-androideabi)
                [ -f "$clang_ver/lib/linux/arm/libunwind.a" ] && cp -a "$clang_ver/lib/linux/arm/libunwind.a" "$SYSROOT/usr/lib/" || true
                [ -f "$clang_ver/lib/linux/libclang_rt.builtins-arm-android.a" ] && cp -a "$clang_ver/lib/linux/libclang_rt.builtins-arm-android.a" "$SYSROOT/usr/lib/" || true
                ;;
            x86_64-linux-android)
                [ -f "$clang_ver/lib/linux/x86_64/libunwind.a" ] && cp -a "$clang_ver/lib/linux/x86_64/libunwind.a" "$SYSROOT/usr/lib/" || true
                [ -f "$clang_ver/lib/linux/libclang_rt.builtins-x86_64-android.a" ] && cp -a "$clang_ver/lib/linux/libclang_rt.builtins-x86_64-android.a" "$SYSROOT/usr/lib/" || true
                ;;
            i686-linux-android)
                [ -f "$clang_ver/lib/linux/i386/libunwind.a" ] && cp -a "$clang_ver/lib/linux/i386/libunwind.a" "$SYSROOT/usr/lib/" || true
                [ -f "$clang_ver/lib/linux/libclang_rt.builtins-i686-android.a" ] && cp -a "$clang_ver/lib/linux/libclang_rt.builtins-i686-android.a" "$SYSROOT/usr/lib/" || true
                ;;
        esac
    fi
done

# Ensure API 21+ libraries and start files (crtbegin/crtend) are at usr/lib root
DEFAULT_API="21"
if [ -d "$SYSROOT/usr/lib/$DEFAULT_API" ]; then
    cp -s -a "$SYSROOT/usr/lib/$DEFAULT_API"/* "$SYSROOT/usr/lib/" 2>/dev/null || \
    cp -a "$SYSROOT/usr/lib/$DEFAULT_API"/* "$SYSROOT/usr/lib/" 2>/dev/null || true
fi

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"
