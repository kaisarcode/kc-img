/**
 * kc-img - Image Manipulation Engine
 * Summary: High-performance image resizing and conversion using MagickWand.
 *
 * Author:  KaisarCode
 * Website: [https://kaisarcode.com](https://kaisarcode.com)
 * License: [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)
 */

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#if defined(_WIN32)
#include <direct.h>
#include <io.h>
#include <process.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif
#include <wand/MagickWand.h>

#if defined(_WIN32)
#define KC_IMG_ACCESS _access
#define KC_IMG_X_OK 0
#define KC_IMG_CLOSE _close
#define KC_IMG_RESVG_EXT ".exe"
#else
#define KC_IMG_ACCESS access
#define KC_IMG_X_OK X_OK
#define KC_IMG_CLOSE close
#define KC_IMG_RESVG_EXT ""
#endif

/**
 * Displays application usage help.
 * @param bin Name of the binary.
 * @return void
 */
void kc_img_usage(const char *bin) {
    printf("Usage: %s --input <path> --width <px> [options]\n", bin);
    printf("Options:\n");
    printf("  -i, --input <path>   Source image path (local or URL)\n");
    printf("  -w, --width <px>     Target width\n");
    printf("  -e, --height <px>    Target height (optional)\n");
    printf("  -f, --format <ext>   Output format (default: png)\n");
    printf("  -h, --help           Show help\n");
}

/**
 * Returns the lowercase extension of the input path.
 * @param input Source path or URL.
 * @return const char * Extension pointer or NULL.
 */
const char *kc_img_extension(const char *input) {
    const char *tail = strrchr(input, '/');
    const char *name = (tail != NULL) ? tail + 1 : input;
    const char *ext = strrchr(name, '.');
    return (ext != NULL && *(ext + 1) != '\0') ? ext + 1 : NULL;
}

/**
 * Returns the ecosystem architecture directory name.
 * @return const char * Architecture name.
 */
const char *kc_img_arch(void) {
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
 * Resolves the resvg executable path.
 * @return const char * Executable path or NULL.
 */
const char *kc_img_resvg_path(void) {
    static char path[1024];
    const char *env = getenv("KC_RESVG_BIN");
    const char *workspace = getenv("KC_WORKSPACE");
    const char *arch = kc_img_arch();
    if (env != NULL && KC_IMG_ACCESS(env, KC_IMG_X_OK) == 0) return env;
    if (workspace != NULL) {
        snprintf(path, sizeof(path), "%s/lib/resvg/%s/bin/resvg%s", workspace, arch, KC_IMG_RESVG_EXT);
        if (KC_IMG_ACCESS(path, KC_IMG_X_OK) == 0) return path;
    }
    snprintf(path, sizeof(path), "/usr/local/lib/kaisarcode/%s/resvg%s", arch, KC_IMG_RESVG_EXT);
    if (KC_IMG_ACCESS(path, KC_IMG_X_OK) == 0) return path;
    return NULL;
}

/**
 * Reports the latest Magick exception to stderr.
 * @param wand MagickWand instance.
 * @param prefix Error label.
 * @return void
 */
void kc_img_report(MagickWand *wand, const char *prefix) {
    ExceptionType severity;
    char *desc = MagickGetException(wand, &severity);
    if (desc != NULL && *desc != '\0') fprintf(stderr, "%s: %s\n", prefix, desc);
    MagickRelinquishMemory(desc);
}

/**
 * Renders SVG input through resvg to a temporary PNG.
 * @param wand MagickWand instance that receives the rendered image.
 * @param input Source path or URL.
 * @param w Target width.
 * @param h Target height.
 * @return int 0 on success, 1 on failure.
 */
int kc_img_read_svg(MagickWand *wand, const char *input, int w, int h) {
    char tmp[] = "/tmp/kc-img-svg-XXXXXX";
    char width[32];
    char height[32];
    const char *resvg = kc_img_resvg_path();
    char *argv[] = {(char *) resvg, "-w", width, "-h", height, (char *) input, tmp, NULL};
    if (resvg == NULL) return 1;
    int fd = mkstemp(tmp);
    if (fd < 0) return 1;
    KC_IMG_CLOSE(fd);
    unlink(tmp);
    snprintf(width, sizeof(width), "%d", w);
    snprintf(height, sizeof(height), "%d", h);
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

/**
 * Loads the source image into the MagickWand instance.
 * @param wand MagickWand instance.
 * @param input Source path or URL.
 * @param w Target width.
 * @param h Target height.
 * @param svg_mode Whether the input is SVG.
 * @return int 0 on success, 1 on failure.
 */
int kc_img_load(MagickWand *wand, const char *input, int w, int h, int svg_mode) {
    MagickSetResolution(wand, w * 2, h * 2);
    if (svg_mode != 0) return kc_img_read_svg(wand, input, w, h);
    return (MagickReadImage(wand, input) == MagickFalse) ? 1 : 0;
}

/**
 * Applies proportional resize and centered extent to a fixed box.
 * @param wand MagickWand instance with image loaded.
 * @param w Target width.
 * @param h Target height.
 * @return int 0 on success, 1 on failure.
 */
int kc_img_extent(MagickWand *wand, int w, int h) {
    MagickBooleanType status;
    size_t orig_w = MagickGetImageWidth(wand);
    size_t orig_h = MagickGetImageHeight(wand);
    PixelWand *background = NewPixelWand();
    size_t fit_w;
    size_t fit_h;
    ssize_t off_x;
    ssize_t off_y;
    PixelSetColor(background, "none");
    MagickSetImageBackgroundColor(wand, background);
    if (orig_w == 0 || orig_h == 0) return 1;
    if ((size_t) w * orig_h <= (size_t) h * orig_w) {
        fit_w = (size_t) w;
        fit_h = (orig_h * fit_w) / orig_w;
    } else {
        fit_h = (size_t) h;
        fit_w = (orig_w * fit_h) / orig_h;
    }
    if (fit_w == 0) fit_w = 1;
    if (fit_h == 0) fit_h = 1;
    status = MagickResizeImage(wand, fit_w, fit_h, LanczosFilter, 1.0);
    if (status == MagickFalse) return 1;
    off_x = -((ssize_t) w / 2) + ((ssize_t) MagickGetImageWidth(wand) / 2);
    off_y = -((ssize_t) h / 2) + ((ssize_t) MagickGetImageHeight(wand) / 2);
    status = MagickExtentImage(wand, w, h, off_x, off_y);
    if (status == MagickFalse) return 1;
    status = MagickSetImageAlphaChannel(wand, ActivateAlphaChannel);
    MagickSetImageCompressionQuality(wand, 95);
    background = DestroyPixelWand(background);
    return (status == MagickFalse) ? 1 : 0;
}

/**
 * Processes image transformation and outputs binary blob to stdout.
 * @param wand MagickWand instance with image loaded.
 * @param w Target width.
 * @param h Target height.
 * @param fmt Output format string.
 * @param svg_mode Whether the input is SVG.
 * @return int 0 on success, 1 on failure.
 */
int kc_img_process(MagickWand *wand, int w, int h, const char *fmt, int svg_mode) {
    MagickBooleanType status = MagickSetImageFormat(wand, fmt);
    size_t orig_w;
    size_t orig_h;
    size_t length = 0;
    unsigned char *blob;
    (void) svg_mode;
    if (status == MagickFalse) return 1;
    if (h <= 0) {
        orig_w = MagickGetImageWidth(wand);
        orig_h = MagickGetImageHeight(wand);
        h = (orig_w > 0) ? (int) ((orig_h * (size_t) w) / orig_w) : w;
        if (h <= 0) h = 1;
        status = MagickResizeImage(wand, w, h, LanczosFilter, 1.0);
        if (status == MagickFalse) return 1;
    }
    if (h > 0 && kc_img_extent(wand, w, h) != 0) return 1;
    MagickSetImageCompressionQuality(wand, 95);
    blob = MagickGetImagesBlob(wand, &length);
    if (blob == NULL) return 1;
    fwrite(blob, 1, length, stdout);
    MagickRelinquishMemory(blob);
    return 0;
}

/**
 * Application entry point.
 * @param argc Argument count.
 * @param argv Argument vector.
 * @return int Process status code.
 */
int main(int argc, char **argv) {
    char *input = NULL;
    char *fmt = "png";
    const char *ext;
    int width = 0, height = 0;
    int svg_mode = 0;
    MagickWandGenesis();
    MagickWand *wand = NewMagickWand();
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            kc_img_usage(argv[0]);
            return 0;
        }
        if ((strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--input") == 0) && i + 1 < argc) {
            input = argv[++i];
        } else if ((strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--width") == 0) && i + 1 < argc) {
            width = atoi(argv[++i]);
        } else if ((strcmp(argv[i], "-e") == 0 || strcmp(argv[i], "--height") == 0) && i + 1 < argc) {
            height = atoi(argv[++i]);
        } else if ((strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--format") == 0) && i + 1 < argc) {
            fmt = argv[++i];
        }
    }
    if (!input || width <= 0) {
        kc_img_usage(argv[0]);
        return 1;
    }
    ext = kc_img_extension(input);
    svg_mode = (ext != NULL && strcasecmp(ext, "svg") == 0) ? 1 : 0;
    if (svg_mode != 0 && height <= 0) height = width;
    if (kc_img_load(wand, input, width, (height > 0) ? height : width, svg_mode) != 0) {
        kc_img_report(wand, "Error reading image");
        return 1;
    }
    int res = kc_img_process(wand, width, height, fmt, svg_mode);
    if (res != 0) {
        kc_img_report(wand, "Error processing image");
    }
    wand = DestroyMagickWand(wand);
    MagickWandTerminus();
    return res;
}
