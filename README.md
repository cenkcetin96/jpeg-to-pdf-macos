# JPEG to PDF for macOS

**Paper PDF** is a free, offline Mac app that turns multiple JPEG images into individual PDFs. No account, uploads, or subscription.

## Download

[**Download Paper PDF for macOS — Apple silicon + Intel**](https://github.com/cenkcetin96/jpeg-to-pdf-macos/releases/latest/download/Paper-PDF-macOS-universal.zip)

Requires **macOS 13 Ventura or later**. The universal download includes both Apple silicon and Intel code.

1. Download and unzip the app.
2. Drag **Paper PDF.app** into your **Applications** folder.
3. Open Paper PDF, then choose images or drag JPEGs into the window.
4. Click **Export PDF…** beside an image to choose its PDF filename and destination.

### First launch

The release is ad-hoc signed and **not Apple Developer ID signed or notarized**. macOS may block the first launch. Review the source and only open the app if you trust it. Apple's [instructions for opening an app from an unidentified developer](https://support.apple.com/en-us/102445) explain the per-app approval in **System Settings → Privacy & Security → Open Anyway**. No security settings need to be disabled globally.

A SHA-256 checksum file is included with each release. To check your download, place both files in the same folder and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Features

- Import multiple `.jpg` / `.jpeg` files using the native file picker or drag and drop.
- Export one single-page PDF per image, with a native Save dialog.
- Preserve image aspect ratio, decoded pixel dimensions, and camera orientation.
- Open the app or add images from its Mac menu bar icon.
- Close the window while keeping the menu bar icon available. Choose **Quit Paper PDF** to exit.
- Open JPEGs through Finder's **Open With → Paper PDF**.
- Uses native SwiftUI, AppKit, ImageIO, Core Graphics, and PDFKit. No third-party runtime dependencies.

## Privacy and limits

Images are processed entirely on your Mac. The app has no network calls, telemetry, account system, or cloud storage. PDF data stays in memory until exported; removing images or quitting clears the app's list.

Pages fit each image at 96 pixels per inch, scaling down only when necessary to stay within the PDF page size limit. PDFs can be larger than the original JPEGs. Large images and batches require more memory. Exports are individual; there is no merged document or automatic bulk export. Automatic launch at login is not enabled.

## Build from source

Requires a Mac and Apple's Xcode Command Line Tools with Swift 5.7 or later. Both architectures are cross-compiled using the installed macOS SDK.

```sh
git clone https://github.com/cenkcetin96/jpeg-to-pdf-macos.git
cd jpeg-to-pdf-macos
./scripts/build.sh
./scripts/test.sh
open 'dist/Paper PDF.app'
```

The build script produces an ad-hoc signed universal app, a ZIP download, and `SHA256SUMS.txt` in `dist/`. A Developer ID certificate and Apple notarization are separate steps for trusted public distribution.

The smoke tests check portrait, landscape, EXIF rotation, PDF page count and dimensions, invalid file rejection, both binary architectures, bundle metadata, and the local signature. Conversion and native import/export were exercised on Apple silicon; the Intel slice is cross-compiled, not runtime-tested on Intel hardware.

## License

MIT. See [LICENSE](LICENSE).
