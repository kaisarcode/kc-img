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
SYS_BIN_DIR="/usr/local/bin"
SYS_LIB_DIR="/usr/local/lib/kaisarcode"
DEPS="imagemagick resvg"

# @brief Prints an error message and exits.
# @param $1 Error message text.
# @return 1 on failure.
fail() {
    printf "Error: %s\n" "$1"
    exit 1
}

# @brief Verifies that the installer is running on Linux.
# @return 0 on success.
require_linux() {
    if [ "$(uname -s)" != "Linux" ]; then
        fail "install.sh currently targets Linux only."
    fi
}

# @brief Verifies the required system tools.
# @return 0 on success.
require_tools() {
    command -v tar >/dev/null 2>&1 || fail "tar is required."
    command -v cp >/dev/null 2>&1 || fail "cp is required."
    command -v wget >/dev/null 2>&1 || fail "wget is required."
    command -v sudo >/dev/null 2>&1 || fail "sudo is required."
}

# @brief Detects the current machine architecture.
# @return 0 on success.
detect_arch() {
    case "$(uname -m)" in
        x86_64) printf "x86_64" ;;
        aarch64) printf "aarch64" ;;
        arm64) printf "aarch64" ;;
        armv8*|arm64-v8a) printf "arm64-v8a" ;;
        *) fail "Unsupported architecture: $(uname -m)" ;;
    esac
}

# @brief Downloads one remote asset to a local path.
# @param $1 Source URL.
# @param $2 Output file path.
# @return 0 on success.
download_asset() {
    url="$1"
    out="$2"
    wget -qO "$out" "$url"
}

# @brief Installs one dependency tree for the current architecture.
# @param $1 Dependency name.
# @param $2 Target architecture.
# @return 0 on success.
install_dep() {
    dep="$1"
    arch="$2"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    download_asset "$DEPS_REPO_ARCHIVE" "$tmp_dir/kc-deps-master.tar.gz"
    tar -xzf "$tmp_dir/kc-deps-master.tar.gz" -C "$tmp_dir"
    src_dir="$tmp_dir/kc-deps-master/lib/${dep}/${arch}"
    [ -d "$src_dir" ] || fail "Dependency not found in kc-deps: ${dep}/${arch}"
    sudo mkdir -p "${SYS_LIB_DIR}/${dep}"
    sudo cp -a "$src_dir" "${SYS_LIB_DIR}/${dep}/"

    rm -rf "$tmp_dir"
    trap - RETURN
}

# @brief Installs the binary for one target architecture.
# @param $1 Target architecture.
# @return 0 on success.
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

# @brief Runs the installer entrypoint.
# @return 0 on success.
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
