# kc-img - Multi-architecture Makefile
# Summary: Build system with per-app artifacts and shared dependency roots.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/gpl-3.0.html

NAME       = kc-img
SRC        = src/main.c src/resvg.c
BIN_ROOT   = bin
TOOLCHAIN_ROOT = /usr/local/share/kaisarcode/toolchains
WORK_ROOT  = $(abspath ../..)
IM_DEV_ROOT = $(WORK_ROOT)/kc-deps/lib/imagemagick
IM_SYS_ROOT = /usr/local/lib/kaisarcode/imagemagick
IM_HEADER  = include/ImageMagick-6/wand/MagickWand.h

NDK_VER     = android-ndk-r27c
NDK_HOST    = linux-x86_64
NDK_ROOT    = $(TOOLCHAIN_ROOT)/ndk/$(NDK_VER)
NDK_BIN     = $(NDK_ROOT)/toolchains/llvm/prebuilt/$(NDK_HOST)/bin

CC_x86_64    = gcc
CC_aarch64   = aarch64-linux-gnu-gcc
NDK_API      = 24
CC_arm64_v8a = $(NDK_BIN)/aarch64-linux-android$(NDK_API)-clang
CC_win64     = x86_64-w64-mingw32-gcc

CFLAGS  = -Wall -Wextra -Werror -O3 -std=c11 \
	-DMAGICKCORE_QUANTUM_DEPTH=16 -DMAGICKCORE_HDRI_ENABLE=0
WINSOCK = -lws2_32 -ladvapi32 -lgdi32 -luser32 -lurlmon -lpthread

.PHONY: all clean build_arch x86_64 aarch64 arm64-v8a win64

all: x86_64 aarch64 arm64-v8a win64

x86_64:
	$(MAKE) build_arch ARCH=x86_64 CC="$(CC_x86_64)" EXT=""

aarch64:
	$(MAKE) build_arch ARCH=aarch64 CC="$(CC_aarch64)" EXT=""

arm64-v8a:
	@if [ ! -f "$(CC_arm64_v8a)" ]; then \
		echo "[ERROR] NDK Compiler not found at: $(CC_arm64_v8a)"; \
		exit 1; \
	fi
	$(MAKE) build_arch ARCH=arm64-v8a CC="$(CC_arm64_v8a)" EXT=""

win64:
	$(MAKE) build_arch ARCH=win64 CC="$(CC_win64)" EXT=".exe" \
	CFLAGS="$(CFLAGS) -D_WIN32_WINNT=0x0601"

build_arch:
	mkdir -p $(BIN_ROOT)/$(ARCH)
	$(eval IM_ROOT = $(if $(wildcard $(IM_DEV_ROOT)/$(ARCH)/$(IM_HEADER)),$(IM_DEV_ROOT),$(IM_SYS_ROOT)))
	$(eval IM_INC = $(IM_ROOT)/$(ARCH)/include)
	$(eval IM_LIB = $(IM_ROOT)/$(ARCH)/lib)
	$(eval IM_RPATH = -Wl,-rpath,$(IM_DEV_ROOT)/$(ARCH)/lib -Wl,-rpath,$(IM_SYS_ROOT)/$(ARCH)/lib)
	@if [ ! -f "$(IM_ROOT)/$(ARCH)/$(IM_HEADER)" ]; then \
		echo "[ERROR] ImageMagick headers not found under $(IM_ROOT)/$(ARCH)"; \
		exit 1; \
	fi
	$(CC) $(CFLAGS) -I$(IM_INC)/ImageMagick-6 -I$(IM_INC) $(SRC) -o \
	$(BIN_ROOT)/$(ARCH)/$(NAME)$(EXT) \
	$(if $(findstring win64,$(ARCH)),$(IM_LIB)/libMagickWand-6.Q16.a $(IM_LIB)/libMagickCore-6.Q16.a $(IM_LIB)/libpng16.a $(IM_LIB)/libz.a $(WINSOCK),$(IM_LIB)/libMagickWand-6.Q16.so $(IM_LIB)/libMagickCore-6.Q16.so $(IM_RPATH))

clean:
	rm -rf $(BIN_ROOT)
