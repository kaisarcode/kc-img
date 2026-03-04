#!/bin/bash
# test.sh - Automated test suite for kc-img
# Summary: Tiered testing for KCS, Ecosystem compliance, and ImageMagick logic.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

# @brief Prints failure details and exits.
# @param message Error description.
# @return 1 on failure.
fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

# @brief Prints success details.
# @param message Success description.
# @return 0 on success.
pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
}

# @brief Loads KC_WORKSPACE from the nearest .kcrc file.
# @return 0 on success.
load_env() {
    SEARCH_DIR=$(pwd)
    while [ "$SEARCH_DIR" != "/" ]; do
        if [ -f "$SEARCH_DIR/.kcrc" ]; then
            . "$SEARCH_DIR/.kcrc"
            break
        fi
        SEARCH_DIR=$(dirname "$SEARCH_DIR")
    done
    if [ -z "$KC_WORKSPACE" ]; then
        fail "KC_WORKSPACE not found."
    fi
}

# @brief Prepares environment and verifies binary and shared library paths.
# @return 0 on success.
test_setup() {
    ARCH=$(uname -m)
    [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ] || ARCH="arm64-v8a"
    KC_BIN_EXEC="$KC_WORKSPACE/bin/kaisarcode/$ARCH/kc-img"
    IM_LIB_DIR="$KC_WORKSPACE/lib/imagemagick/$ARCH/lib"
    IM_BIN_DIR="$KC_WORKSPACE/lib/imagemagick/$ARCH/bin"
    KC_RESVG_EXEC="$KC_WORKSPACE/lib/resvg/$ARCH/bin/resvg"

    if [ ! -f "$KC_BIN_EXEC" ]; then
        fail "Binary not found at $KC_BIN_EXEC"
    fi

    if [ ! -d "$IM_LIB_DIR" ]; then
        fail "ImageMagick libraries not found at $IM_LIB_DIR"
    fi

    export LD_LIBRARY_PATH="$IM_LIB_DIR:$LD_LIBRARY_PATH"
    export KC_RESVG_BIN="$KC_RESVG_EXEC"
    KC_IDENTIFY="$IM_BIN_DIR/identify"
    KC_CONVERT="$IM_BIN_DIR/convert"
    pass "Environment verified: using $KC_BIN_EXEC"
}

# @brief Executes the KCS validator if available.
# @return 0 on success.
test_kcs() {
    if [ -f "$KC_WORKSPACE/bin/kcs" ]; then
        find . -type f -not -path '*/.*' -not -path './bin/*' \
            -exec "$KC_WORKSPACE/bin/kcs" {} + || fail "KCS validation failed."
        pass "General: KCS compliance verified."
    else
        LOC=$(wc -l < src/main.c)
        if [ "$LOC" -gt 300 ]; then
            fail "KCS: src/main.c exceeds 300 lines ($LOC)."
        fi
        pass "General: KCS functional atomicity verified ($LOC lines)."
    fi
}

# @brief Verifies CLI help and fail-fast argument handling.
# @return 0 on success.
test_cli() {
    if ! "$KC_BIN_EXEC" --help | grep -q "Usage:"; then
        fail "CLI: Help flag failed."
    fi
    pass "CLI: Help flag verified."

    if "$KC_BIN_EXEC" --input missing.png >/dev/null 2>&1; then
        fail "CLI: Missing width should fail."
    fi
    if "$KC_BIN_EXEC" --width 100 >/dev/null 2>&1; then
        fail "CLI: Missing input should fail."
    fi
    pass "CLI: Fail-fast argument validation verified."
}

# @brief Verifies image processing logic and piping capability.
# @return 0 on success.
test_functional() {
    T_OUT="/tmp/kc_img_test.png"
    T_BOX="/tmp/kc_img_box.png"
    T_SRC="/tmp/kc_img_src.png"
    T_ALPHA_SRC="/tmp/kc_img_alpha_src.png"
    T_ALPHA_OUT="/tmp/kc_img_alpha_out.png"
    T_SVG="/tmp/kc_img_test.svg"
    T_SVG_OUT="/tmp/kc_img_svg.png"

    if ! "$KC_BIN_EXEC" --input "xc:red" --width 100 --format png > "$T_OUT"; then
        fail "Functional: Image generation failed."
    fi

    if [ ! -s "$T_OUT" ]; then
        fail "Functional: Output file is empty."
    fi

    FILE_INFO=$(file "$T_OUT")
    if [[ ! "$FILE_INFO" == *"PNG image data"* ]]; then
        fail "Functional: Output is not a valid PNG."
    fi

    if ! "$KC_CONVERT" -size 200x100 xc:red "$T_SRC" >/dev/null 2>&1; then
        fail "Functional: Test source generation failed."
    fi

    if ! "$KC_BIN_EXEC" --input "$T_SRC" --width 50 --height 50 --format png > "$T_BOX"; then
        fail "Functional: Fixed-box resize failed."
    fi

    BOX_SIZE=$("$KC_IDENTIFY" -format "%wx%h" "$T_BOX" 2>/dev/null)
    if [ "$BOX_SIZE" != "50x50" ]; then
        fail "Functional: Fixed-box dimensions incorrect ($BOX_SIZE)."
    fi

    if ! "$KC_CONVERT" -size 200x100 xc:none -fill red -draw "rectangle 0,0 199,99" "$T_ALPHA_SRC" >/dev/null 2>&1; then
        fail "Functional: Alpha source generation failed."
    fi

    if ! "$KC_BIN_EXEC" --input "$T_ALPHA_SRC" --width 50 --height 50 --format png > "$T_ALPHA_OUT"; then
        fail "Functional: Alpha-preserving resize failed."
    fi

    ALPHA_CORNER=$("$KC_IDENTIFY" -format "%[pixel:p{0,0}]" "$T_ALPHA_OUT" 2>/dev/null)
    if [ "$ALPHA_CORNER" != "srgba(0,0,0,0)" ] && [ "$ALPHA_CORNER" != "none" ]; then
        fail "Functional: Alpha corner lost transparency ($ALPHA_CORNER)."
    fi

    cat > "$T_SVG" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60">
  <rect width="120" height="60" fill="red"/>
</svg>
EOF

    if [ ! -x "$KC_RESVG_EXEC" ]; then
        fail "Functional: resvg binary not found at $KC_RESVG_EXEC"
    fi
    if ! "$KC_BIN_EXEC" --input "$T_SVG" --width 80 --format png > "$T_SVG_OUT"; then
        fail "Functional: SVG rendering failed."
    fi
    SVG_SIZE=$("$KC_IDENTIFY" -format "%wx%h" "$T_SVG_OUT" 2>/dev/null)
    if [ "$SVG_SIZE" != "80x80" ]; then
        fail "Functional: SVG default sizing incorrect ($SVG_SIZE)."
    fi

    rm -f "$T_OUT" "$T_BOX" "$T_SRC" "$T_ALPHA_SRC" "$T_ALPHA_OUT" "$T_SVG" "$T_SVG_OUT"
    pass "Functional: Image processing, extent, and SVG coverage verified."
}

# @brief Entry point for the automated test suite.
# @return 0 on success.
run_tests() {
    load_env
    test_setup
    test_kcs
    test_cli
    test_functional
    pass "All tests passed successfully."
}

run_tests

exit 0
