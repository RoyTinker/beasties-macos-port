#!/bin/sh
# Build Beast.app into port/build/. Usage: port/build-app.sh [debug|release]
set -e
cd "$(dirname "$0")"
CONFIG=${1:-release}
swift build -c "$CONFIG" --arch arm64 --arch x86_64
BIN=$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)
APP=build/Beast.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Beast" "$APP/Contents/MacOS/Beast"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"          # ad-hoc signature, enough to run locally
echo "built $APP"
