/**
 * kc-img-resvg - resvg integration helpers
 * Summary: Runtime lookup and SVG rendering support for kc-img.
 *
 * Author:  KaisarCode
 * Website: https://kaisarcode.com
 * License: GNU GPL v3.0
 */

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <string.h>
#if defined(_WIN32)
#include <io.h>
#include <process.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif
#include "resvg.h"

#if defined(_WIN32)
#define KC_IMG_ACCESS _access
#define KC_IMG_X_OK 0
#define KC_IMG_CLOSE _close
#define KC_IMG_RESVG_EXT ".exe"
#define KC_IMG_PATH_SEP ';'
#else
#define KC_IMG_ACCESS access
#define KC_IMG_X_OK X_OK
#define KC_IMG_CLOSE close
#define KC_IMG_RESVG_EXT ""
#define KC_IMG_PATH_SEP ':'
#endif

/**
 * Returns the ecosystem architecture directory name.
 * @return const char * Architecture name.
 */
static const char *kc_img_arch(void) {
#if defined(_WIN32)
    return "win64";
#elif defined(__ANDROID__)
    return "arm64-v8a";
#elif defined(__aarch64__)
    return "aarch64";
#else
    return "x86_64";
#endif
}

/**
 * Searches one executable name in PATH.
 * @param name Executable file name.
 * @return const char * Resolved executable path or NULL.
 */
static const char *kc_img_find_in_path(const char *name) {
    static char path[1024];
    const char *path_env = getenv("PATH");
    if (path_env == NULL || *path_env == '\0') return NULL;
    const char *cursor = path_env;
    while (*cursor != '\0') {
        const char *sep = strchr(cursor, KC_IMG_PATH_SEP);
        size_t len = (sep != NULL) ? (size_t) (sep - cursor) : strlen(cursor);
        if (len > 0 && len + 1 + strlen(name) + 1 < sizeof(path)) {
            memcpy(path, cursor, len);
            path[len] = '/';
            strcpy(path + len + 1, name);
            if (KC_IMG_ACCESS(path, KC_IMG_X_OK) == 0) return path;
        }
        if (sep == NULL) break;
        cursor = sep + 1;
    }
    return NULL;
}

/**
 * Resolves the resvg executable path.
 * @return const char * Executable path or NULL.
 */
static const char *kc_img_resvg_path(void) {
    static char path[1024];
    const char *arch = kc_img_arch();
    const char *path_hit = kc_img_find_in_path("resvg" KC_IMG_RESVG_EXT);
    if (path_hit != NULL) return path_hit;
    snprintf(path, sizeof(path), "/usr/local/lib/kaisarcode/resvg/%s/bin/resvg%s", arch, KC_IMG_RESVG_EXT);
    if (KC_IMG_ACCESS(path, KC_IMG_X_OK) == 0) return path;
    return NULL;
}

/**
 * Renders SVG input through resvg to a temporary PNG.
 * @param wand MagickWand instance that receives the rendered image.
 * @param input Source path or URL.
 * @param width Target width.
 * @param height Target height.
 * @return int 0 on success, 1 on failure.
 */
int kc_img_render_svg(MagickWand *wand, const char *input, int width, int height) {
    char tmp[] = "/tmp/kc-img-svg-XXXXXX";
    char arg_width[32];
    char arg_height[32];
    const char *resvg = kc_img_resvg_path();
    char *argv[] = {(char *) resvg, "-w", arg_width, "-h", arg_height, (char *) input, tmp, NULL};
    if (resvg == NULL) return 1;
    int fd = mkstemp(tmp);
    if (fd < 0) return 1;
    KC_IMG_CLOSE(fd);
    unlink(tmp);
    snprintf(arg_width, sizeof(arg_width), "%d", width);
    snprintf(arg_height, sizeof(arg_height), "%d", height);
#if defined(_WIN32)
    if (_spawnvp(_P_WAIT, argv[0], (const char *const *) argv) != 0) return 1;
#else
    pid_t pid = fork();
    if (pid < 0) return 1;
    if (pid == 0) {
        execvp(argv[0], argv);
        _exit(1);
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) return 1;
#endif
    int result = (MagickReadImage(wand, tmp) == MagickFalse) ? 1 : 0;
    unlink(tmp);
    return result;
}
