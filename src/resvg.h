/**
 * kc-img-resvg - resvg integration helpers
 * Summary: Runtime lookup and SVG rendering support for kc-img.
 *
 * Author:  KaisarCode
 * Website: https://kaisarcode.com
 * License: GNU GPL v3.0
 */

#ifndef KC_IMG_RESVG_H
#define KC_IMG_RESVG_H

#include <wand/MagickWand.h>

/**
 * Renders an SVG input through resvg into the provided MagickWand.
 * @param wand MagickWand instance that receives the rendered image.
 * @param input Source SVG path.
 * @param width Target width.
 * @param height Target height.
 * @return 0 on success, 1 on failure.
 */
int kc_img_render_svg(MagickWand *wand, const char *input, int width, int height);

#endif
