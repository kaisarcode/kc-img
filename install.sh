#!/bin/bash
# install.sh - Production installer for kc-img on Linux.
# Summary: Installs the current-architecture binary plus ImageMagick and resvg runtime deps from master using Git SSH.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

APP_ID="kc-img"
APP_REPO_SSH="git@github.com:kaisarcode/kc-img.git"
DEPS_REPO_SSH="git@github.com:kaisarcode/kc-deps.git"
BRANCH="master"
SYS_BIN_DIR="/usr/local/bin"
SYS_LIB_DIR="/usr/local/lib/kaisarcode"
DEPS="imagemagick resvg"

fail() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

require_linux() {
    [ "$(uname -s)" = "Linux" ] || fail "install.sh currently targets Linux only."
}

require_tools() {
    command -v git >/dev/null 2>&1 || fail "git is required."
    command -v cp >/dev/null 2>&1 || fail "cp is required."
    command -v install >/dev/null 2>&1 || fail "install is required."
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

clone_repo() {
    repo_url="$1"
    repo_dir="$2"
    git clone --depth 1 --branch "$BRANCH" "$repo_url" "$repo_dir" >/dev/null 2>&1 \
        || fail "Unable to clone repository: $repo_url"
}

install_dep() {
    dep="$1"
    arch="$2"
    src_dir="$DEPS_DIR/lib/$dep/$arch"
    [ -d "$src_dir" ] || fail "Dependency not found in kc-deps: $dep/$arch"
    sudo mkdir -p "$SYS_LIB_DIR/$dep"
    sudo rm -rf "$SYS_LIB_DIR/$dep/$arch"
    sudo cp -a "$src_dir" "$SYS_LIB_DIR/$dep/"
}

install_binary() {
    arch="$1"
    src_bin="$APP_DIR/bin/$arch/$APP_ID"
    [ -f "$src_bin" ] || fail "Binary not found in repository: bin/$arch/$APP_ID"
    sudo mkdir -p "$SYS_BIN_DIR"
    sudo install -m 0755 "$src_bin" "$SYS_BIN_DIR/$APP_ID"
}

main() {
    require_linux
    require_tools
    arch="$(detect_arch)"
    tmp_root="$(mktemp -d)"
    trap 'rm -rf "$tmp_root"' EXIT

    APP_DIR="$tmp_root/$APP_ID"
    DEPS_DIR="$tmp_root/kc-deps"
    clone_repo "$APP_REPO_SSH" "$APP_DIR"
    clone_repo "$DEPS_REPO_SSH" "$DEPS_DIR"

    for dep in $DEPS; do
        install_dep "$dep" "$arch"
    done

    install_binary "$arch"
    printf "%s installed.\n" "$APP_ID"
}

main "$@"
