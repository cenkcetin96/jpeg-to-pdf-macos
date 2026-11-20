#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app='dist/Paper PDF.app'
mkdir -p .build "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
for arch in arm64 x86_64; do
  xcrun swiftc Sources/main.swift -swift-version 5 -O \
    -target "$arch-apple-macosx13.0" \
    -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers \
    -framework ImageIO -framework PDFKit -o ".build/PaperPDF-$arch"
done
xcrun lipo -create .build/PaperPDF-arm64 .build/PaperPDF-x86_64 -output "$app/Contents/MacOS/PaperPDF"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" dist/Paper-PDF-macOS-universal.zip
(cd dist && shasum -a 256 Paper-PDF-macOS-universal.zip > SHA256SUMS.txt)
printf 'Built %s\n' "$app" 'dist/Paper-PDF-macOS-universal.zip'
