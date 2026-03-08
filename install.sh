#!/bin/bash
# install.sh - Production installer for kc-img on Linux.
# Summary: Installs the current-architecture binary plus ImageMagick and resvg runtime deps from master using wget.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

APP_ID="kc-img"
APP_REPO_RAW="https://raw.githubusercontent.com/kaisarcode/kc-img/master"
DEPS_REPO_ARCHIVE="https://codeload.github.com/kaisarcode/kc-deps/tar.gz/refs/heads/master"
DEPS_REPO_MEDIA="https://media.githubusercontent.com/media/kaisarcode/kc-deps/master"
DEPS_REPO_RAW="https://raw.githubusercontent.com/kaisarcode/kc-deps/master"
SYS_BIN_DIR="/usr/local/bin"
SYS_LIB_DIR="/usr/local/lib/kaisarcode"
DEPS="imagemagick resvg"

fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

fail_unavailable() {
    fail "Remote asset is not available yet (repo may still be private): $1"
}

require_linux() {
    [ "$(uname -s)" = "Linux" ] || fail "install.sh currently targets Linux only."
}

require_tools() {
    command -v tar >/dev/null 2>&1 || fail "tar is required."
    command -v cp >/dev/null 2>&1 || fail "cp is required."
    command -v wget >/dev/null 2>&1 || fail "wget is required."
    command -v sudo >/dev/null 2>&1 || fail "sudo is required."
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) printf "x86_64" ;;
        aarch64|arm64) printf "aarch64" ;;
        armv8*|arm64-v8a) printf "arm64-v8a" ;;
        *) fail "Unsupported architecture: $(uname -m)" ;;
    esac
}

download_asset() {
    url="$1"
    out="$2"
    if ! wget -qO "$out" "$url"; then
        rm -f "$out"
        fail_unavailable "$url"
    fi
    [ -s "$out" ] || { rm -f "$out"; fail_unavailable "$url"; }
}

download_dep_asset() {
    rel="$1"
    out="$2"
    if wget -qO "$out" "${DEPS_REPO_MEDIA}/${rel}" && [ -s "$out" ]; then
        return 0
    fi
    rm -f "$out"
    download_asset "${DEPS_REPO_RAW}/${rel}" "$out"
}

install_dep() {
    dep="$1"
    arch="$2"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    download_asset "$DEPS_REPO_ARCHIVE" "$tmp_dir/kc-deps-master.tar.gz"
    tar -xzf "$tmp_dir/kc-deps-master.tar.gz" -C "$tmp_dir"
    case "$dep" in
        imagemagick)
            base_rel="lib/${dep}/${arch}/lib"
            src_dir="$tmp_dir/kc-deps-master/$base_rel"
            dst_dir="${SYS_LIB_DIR}/${dep}/${arch}/lib"
            ;;
        resvg)
            base_rel="lib/${dep}/${arch}/bin"
            src_dir="$tmp_dir/kc-deps-master/$base_rel"
            dst_dir="${SYS_LIB_DIR}/${dep}/${arch}/bin"
            ;;
        *)
            fail "Unsupported dependency: $dep"
            ;;
    esac
    [ -d "$src_dir" ] || fail "Dependency runtime not found in kc-deps: $base_rel"
    sudo mkdir -p "$dst_dir"
    (
        CDPATH= cd -- "$src_dir"
        find . -mindepth 1 | sort
    ) | while IFS= read -r rel; do
        src_path="$src_dir/$rel"
        dst_path="$dst_dir/${rel#./}"
        if [ -d "$src_path" ]; then
            sudo mkdir -p "$dst_path"
            continue
        fi
        sudo mkdir -p "$(dirname "$dst_path")"
        if [ -L "$src_path" ]; then
            sudo ln -sfn "$(readlink "$src_path")" "$dst_path"
            continue
        fi
        mode=0644
        [ -x "$src_path" ] && mode=0755
        download_dep_asset "$base_rel/${rel#./}" "$tmp_dir/payload.bin"
        sudo install -m "$mode" "$tmp_dir/payload.bin" "$dst_path"
    done

    rm -rf "$tmp_dir"
    trap - RETURN
}

install_binary() {
    arch="$1"
    bin_rel="bin/${arch}/${APP_ID}"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    download_asset "${APP_REPO_RAW}/${bin_rel}" "$tmp_dir/${APP_ID}"
    sudo mkdir -p "$SYS_BIN_DIR"
    sudo install -m 0755 "$tmp_dir/${APP_ID}" "$SYS_BIN_DIR/${APP_ID}"

    rm -rf "$tmp_dir"
    trap - RETURN
}

main() {
    require_linux
    require_tools
    arch="$(detect_arch)"

    for dep in $DEPS; do
        install_dep "$dep" "$arch"
    done

    install_binary "$arch"
    printf "%s installed.\n" "${APP_ID}"
}

main "$@"
