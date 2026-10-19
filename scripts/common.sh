#!/usr/bin/env bash
# common.sh - Shared utility functions for building and packaging SDKs/sysroots
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() {
    echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"
}

log_step() {
    echo -e "  \033[1;32m✓\033[0m $*"
}

log_warn() {
    echo -e "\033[1;33mwarning:\033[0m $*" >&2
}

log_err() {
    echo -e "\033[1;31merror:\033[0m $*" >&2
    exit 1
}

fetch() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    log "Downloading $url..."
    curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors -sS -o "$dest" "$url"
}

fetch_any() {
    local dest="$1"
    shift
    for url in "$@"; do
        if curl --fail --location --retry 2 -sS -o "$dest" "$url" 2>/dev/null; then
            log_step "Downloaded $url"
            return 0
        fi
    done
    log_err "Failed to download from any mirror: $*"
}

apt_install() {
    sudo apt-get update -qq || true
    sudo apt-get install -y --no-install-recommends software-properties-common -qq 2>/dev/null || true
    sudo add-apt-repository -y universe 2>/dev/null || true
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends -qq "$@"
}

clean_sysroot() {
    local root="$1"
    log "Cleaning and pruning $root..."
    
    # Remove documentation, man pages, locales, info
    rm -rf "$root"/usr/share/{doc,man,info,locale,zoneinfo} 2>/dev/null || true
    rm -rf "$root"/share/{doc,man,info,locale} 2>/dev/null || true

    # Strip debugging symbols from shared libraries
    find "$root" -type f -name "*.so*" -exec strip --strip-unneeded {} + 2>/dev/null || true
    find "$root" -type f -name "*.dylib" -exec strip -x {} + 2>/dev/null || true

    # Sanitize GNU ld scripts (e.g. libc.so, libm.so) with hardcoded absolute host paths like /usr/<arch>/lib64/ or /lib32/
    find "$root" -type f -name "*.so" | while read -r f; do
        if file "$f" | grep -q "ASCII text"; then
            sed -i -E 's|/usr/[a-zA-Z0-9_-]+/lib[0-9]*/||g; s|/usr/[a-zA-Z0-9_-]+/lib/||g; s|/usr/lib[0-9]*/||g; s|/lib[0-9]*/||g; s|/lib/||g' "$f"
        fi
    done
}

pack_tarball() {
    local src_dir="$1"
    local out_tar="$2"
    mkdir -p "$(dirname "$out_tar")"

    local abs_out
    abs_out="$(cd "$(dirname "$out_tar")" && pwd)/$(basename "$out_tar")"

    # Verify src_dir contains files
    local file_count
    file_count="$(find "$src_dir" -type f | wc -l)"
    if [ "$file_count" -lt 5 ]; then
        log_err "Sysroot at $src_dir is almost empty (found only $file_count files)! Refusing to package an empty SDK."
    fi

    local tmp_tar
    tmp_tar="$(mktemp -u --tmpdir "tarball-XXXXXX.tar.xz")"

    log "Compressing $src_dir ($file_count files) -> $out_tar ..."
    # Deterministic tar with xz high compression written outside src_dir
    XZ_OPT="-9e -T0" tar -C "$src_dir" -cJf "$tmp_tar" .
    mv -f "$tmp_tar" "$abs_out"
    test -f "$abs_out"

    log_step "Created $out_tar ($(du -h "$abs_out" | cut -f1))"
}
