#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary='dist/Paper PDF.app/Contents/MacOS/PaperPDF'
"$binary" --self-test Tests/Fixtures/portrait.jpg Tests/Fixtures/landscape.jpeg Tests/Fixtures/rotated.jpg > .build/test-results.txt
cat .build/test-results.txt
grep -q 'portrait.jpg: 480×640' .build/test-results.txt
grep -q 'landscape.jpeg: 800×400' .build/test-results.txt
grep -q 'rotated.jpg: 480×640' .build/test-results.txt
printf 'not a JPEG\n' > .build/invalid.jpg
if "$binary" --self-test .build/invalid.jpg > .build/invalid-result.txt 2>&1; then
  printf 'FAIL: invalid JPEG was accepted\n' >&2
  exit 1
fi
grep -q 'not a readable JPEG' .build/invalid-result.txt
printf 'PASS invalid JPEG rejected\n'
plutil -lint 'dist/Paper PDF.app/Contents/Info.plist'
codesign --verify --deep --strict 'dist/Paper PDF.app'
xcrun lipo "$binary" -verify_arch arm64 x86_64
