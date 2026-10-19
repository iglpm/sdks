#!/usr/bin/env bash
# update-upstream.sh - Checks for new upstream releases of toolchains/sysroots
# (e.g. musl-cross-make, Android NDK, FreeBSD, wasi-sdk) and outputs changes.
set -euo pipefail

changes=()

check_github() {
    local repo="$1"
    local var="$2"
    local current="$3"
    local file="$4"
    local latest
    latest="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)"

    if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
        changes+=("$repo: $current -> $latest")
        if [ -f "$file" ]; then
            sed -i "s/${var}=[\"']\?${current}[\"']\?/${var}=\"${latest}\"/" "$file"
        fi
    fi
}

echo "Checking upstream toolchain updates..."
# Example: check Android NDK, MCM, FreeBSD
if [ ${#changes[@]} -gt 0 ]; then
    printf '%s\n' "${changes[@]}"
fi
