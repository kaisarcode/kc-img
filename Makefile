# kc-img - Image Manipulation Engine Makefile
# Summary: Multi-architecture build system for MagickWand integration.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/gpl-3.0.html

ifndef KC_WORKSPACE
$(error KC_WORKSPACE is not defined. Please set it as an environment variable.)
endif

NAME       = kc-img
SRC        = src/main.c
BIN_ROOT   = bin
EXPORT_DIR = $(KC_WORKSPACE)/bin/kaisarcode

# External Library Path
IM_PATH    = $(KC_WORKSPACE)/lib/imagemagick/$(ARCH)

# Toolchains
NDK_VER     = android-ndk-r27c
NDK_HOST    = linux-x86_64
NDK_ROOT    = $(KC_WORKSPACE)/src/toolchains/ndk/$(NDK_VER)
NDK_BIN     = $(NDK_ROOT)/toolchains/llvm/prebuilt/$(NDK_HOST)/bin

CC_x86_64    = gcc
CC_aarch64   = aarch64-linux-gnu-gcc
NDK_API      = 24
CC_arm64_v8a = $(NDK_BIN)/aarch64-linux-android$(NDK_API)-clang
CC_win64     = x86_64-w64-mingw32-gcc

# Compilation Flags
CFLAGS  = -Wall -Wextra -O3 -std=c11 -I$(IM_PATH)/include/ImageMagick-6 \
          -DMAGICKCORE_QUANTUM_DEPTH=16 -DMAGICKCORE_HDRI_ENABLE=0
WINSOCK = -lws2_32 -ladvapi32 -lpng16 -lz -lgdi32 -luser32 -lurlmon -lpthread

.PHONY: all clean build_arch x86_64 aarch64 arm64-v8a win64

all: x86_64 aarch64 arm64-v8a win64

x86_64:
	$(MAKE) build_arch ARCH=x86_64 CC="$(CC_x86_64)" EXT=""

aarch64:
	$(MAKE) build_arch ARCH=aarch64 CC="$(CC_aarch64)" EXT=""

arm64-v8a:
	@if [ ! -d "$(NDK_ROOT)" ]; then echo "NDK not found at $(NDK_ROOT)"; exit 1; fi
	$(MAKE) build_arch ARCH=arm64-v8a CC="$(CC_arm64_v8a)" EXT=""

win64:
	$(MAKE) build_arch ARCH=win64 CC="$(CC_win64)" EXT=".exe"

build_arch:
	@mkdir -p $(BIN_ROOT)/$(ARCH)
	@mkdir -p $(EXPORT_DIR)/$(ARCH)
	$(eval DEV_LIB = $(KC_WORKSPACE)/lib/imagemagick/$(ARCH)/lib)
	$(CC) $(CFLAGS) $(SRC) -o $(EXPORT_DIR)/$(ARCH)/$(NAME)$(EXT) \
	-L$(DEV_LIB) -lMagickWand-6.Q16 -lMagickCore-6.Q16 \
	$(if $(findstring win64,$(ARCH)),$(WINSOCK))
	@printf "\033[32m[OK]\033[0m %s built for %s\n" "$(NAME)" "$(ARCH)"

clean:
	rm -rf $(BIN_ROOT)
	@printf "\033[33m[CLEAN]\033[0m %s local binaries removed\n" "$(NAME)"
