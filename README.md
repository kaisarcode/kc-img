# kc-img

> **Note:** This application is in the development and testing phase, is not ready for production use, and may change without prior notice.

High-performance, deterministic image manipulation engine powered by MagickWand/ImageMagick.

Designed for high-speed server-side image processing, `kc-img` transforms images according to strictly defined dimensions and formats, outputting a binary blob directly to `stdout` for efficient piping or streaming.

## Features

- **Piping Architecture**: Outputs binary image data directly to `stdout`.
- **Dynamic Resizing**: Support for both standard resizing and thumbnailing.
- **Format Conversion**: Convert between common formats (PNG, JPEG, WEBP, etc.).
- **Background Transparency**: Preserves "none" background transparency by default.
- **Native Efficiency**: Built on MagickWand for high-precision Lanczos filtering.

## Usage

```bash
kc-img --input image.jpg --width 800 --format png > output.png
```

### Full Parameter Reference

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--input` | Source image path (can be a local file or a direct URL) | `NULL` (Required) |
| `--width` | Target width in pixels | `0` (Required) |
| `--height` | Target height in pixels (optional) | `0` (Auto-ratio) |
| `--format` | Output image format extension | `png` |
| `--help` | Show help and usage information | `NULL` |

## Testing

`./test.sh` remains a functional suite for `kc-img` itself:

- strict CLI validation
- ImageMagick-based resizing and extent behavior
- alpha preservation
- SVG rendering through `resvg`

## Compilation

```bash
make x86_64
make aarch64
make arm64-v8a
make win64
make all
```

## Technical Logic

- **Lanczos Filtering**: Used for standard resizing when only `--width` is provided to ensure maximum visual fidelity.
- **Thumbnailing**: Used when both `--width` and `--height` are provided for efficient fixed-size generation.
- **Memory Management**: Explicitly manages MagickWand genesis and terminus to ensure zero memory leaks.
- **Stream Output**: Designed to be used in shell pipelines (e.g., `kc-img ... | kc-upload ...`).

---

**Author:** KaisarCode

**Website:** [https://kaisarcode.com](https://kaisarcode.com)

**License:** [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

**Email:** <kaisar@kaisarcode.com>

© 2026 KaisarCode
