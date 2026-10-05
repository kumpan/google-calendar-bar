#!/bin/bash
# Builds CalendarBar.app into ./dist/
#   ./build.sh           signed with Kumpan's Developer ID if installed, else ad-hoc
#   ./build.sh release   also notarizes, staples and zips for distribution
#                        (needs the "CalendarBar" notarytool keychain profile; CI sets NOTARY_KEYCHAIN)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_ID="Developer ID Application: Kumpan Grafisk Form AB (NH4M8452G6)"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/CalendarBar"
APP=".build/CalendarBar.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CalendarBar"
cp Resources/AppIcon.icns "$APP/Contents/Resources/" # regenerate with: swift scripts/make-icon.swift
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>se.kumpan.calendarbar</string>
  <key>CFBundleName</key><string>CalendarBar</string>
  <key>CFBundleExecutable</key><string>CalendarBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
  codesign --force --options runtime --timestamp -s "$SIGN_ID" "$APP" # hardened runtime: required for notarization
else
  [[ "${1:-}" == "release" ]] && { echo "Developer ID certificate not found; can't make a release." >&2; exit 1; }
  echo "Developer ID certificate not found – signing ad-hoc (works on this Mac only)."
  codesign --force --deep -s - "$APP"
fi

mkdir -p dist
rm -rf dist/CalendarBar.app
cp -R "$APP" dist/

if [[ "${1:-}" == "release" ]]; then
  ZIP="dist/CalendarBar-$VERSION.zip"
  ditto -c -k --keepParent dist/CalendarBar.app "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile CalendarBar ${NOTARY_KEYCHAIN:+--keychain "$NOTARY_KEYCHAIN"} --wait
  xcrun stapler staple dist/CalendarBar.app
  rm "$ZIP"
  ditto -c -k --keepParent dist/CalendarBar.app "$ZIP" # re-zip with the stapled ticket
  spctl --assess --type execute -v dist/CalendarBar.app
  echo "Release ready: $ZIP"
else
  echo "Built dist/CalendarBar.app"
fi
