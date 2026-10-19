#!/usr/bin/env bash
# build-linux-musl.sh <target> [out_dir]
# Builds musl libc cross sysroot using musl-cross-make
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-x86_64-unknown-linux-musl}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include"

MCM_COMMIT="227df8b99103f9c59f6570babf892978e293082f"
GCC_VER="14.3.0"
BINUTILS_VER="2.44"
MUSL_VER="1.2.5"
LINUX_VER="6.15.7"

case "$TARGET" in
    x86_64-unknown-linux-musl)
        MUSL_TARGET="x86_64-linux-musl"
        EXTRA_FLAGS=""
        ;;
    i686-unknown-linux-musl)
        MUSL_TARGET="i686-linux-musl"
        EXTRA_FLAGS=""
        ;;
    aarch64-unknown-linux-musl)
        MUSL_TARGET="aarch64-linux-musl"
        EXTRA_FLAGS=""
        ;;
    armv7-unknown-linux-musleabihf)
        MUSL_TARGET="arm-linux-musleabihf"
        EXTRA_FLAGS="--with-arch=armv7-a --with-fpu=vfpv3-d16 --with-float=hard"
        ;;
    arm-unknown-linux-musleabihf)
        MUSL_TARGET="arm-linux-musleabihf"
        EXTRA_FLAGS="--with-arch=armv6 --with-fpu=vfp --with-float=hard"
        ;;
    riscv64gc-unknown-linux-musl)
        MUSL_TARGET="riscv64-linux-musl"
        EXTRA_FLAGS=""
        ;;
    powerpc64le-unknown-linux-musl)
        MUSL_TARGET="powerpc64le-linux-musl"
        EXTRA_FLAGS=""
        ;;
    *)
        log_err "Unknown Linux musl target: $TARGET"
        ;;
esac

log "Building musl sysroot for $TARGET ($MUSL_TARGET)..."

apt_install build-essential bison flex texinfo rsync

MCM_DIR="$WORK/musl-cross-make"
mkdir -p "$MCM_DIR"
fetch "https://github.com/richfelker/musl-cross-make/archive/${MCM_COMMIT}.tar.gz" "$WORK/mcm.tar.gz"
tar -xzf "$WORK/mcm.tar.gz" -C "$MCM_DIR" --strip-components=1

PREFIX="$WORK/prefix"
cat > "$MCM_DIR/config.mak" <<EOF
TARGET = ${MUSL_TARGET}
OUTPUT = ${PREFIX}
GCC_VER = ${GCC_VER}
BINUTILS_VER = ${BINUTILS_VER}
MUSL_VER = ${MUSL_VER}
LINUX_VER = ${LINUX_VER}
DL_CMD = curl --fail --location --silent --show-error --retry 5 --retry-delay 5 --retry-all-errors -C - -o
COMMON_CONFIG += CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2" LDFLAGS="-s"
GCC_CONFIG += --enable-languages=c,c++ --disable-libsanitizer --disable-multilib ${EXTRA_FLAGS}
EOF

make -C "$MCM_DIR" -j"$(nproc)" install

# Copy sysroot from the built toolchain
TARGET_SYSROOT="$PREFIX/$MUSL_TARGET"
if [ -d "$TARGET_SYSROOT" ]; then
    cp -a "$TARGET_SYSROOT"/include/. "$SYSROOT/usr/include/" 2>/dev/null || true
    cp -a "$TARGET_SYSROOT"/lib/. "$SYSROOT/usr/lib/" 2>/dev/null || true
fi

# Fix ld-musl symlinks
for loader in "$SYSROOT/usr/lib"/ld-musl-*.so.1; do
    if [ -L "$loader" ]; then
        ln -sf libc.so "$loader"
    fi
done

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"
