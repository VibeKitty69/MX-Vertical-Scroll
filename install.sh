#!/bin/bash
# Installs by replacing only the binary — preserves macOS Accessibility permission
set -e

APP_NAME="SideScrollConverter"
APP_BUNDLE="$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_BUNDLE"

if [ ! -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "Run ./build.sh first"
    exit 1
fi

pkill "$APP_NAME" 2>/dev/null || true
sleep 0.5

if [ ! -d "$INSTALL_PATH" ]; then
    echo "First install — copying full bundle..."
    cp -r "$APP_BUNDLE" "$INSTALL_PATH"
else
    echo "Updating binary only (preserves Accessibility permission)..."
    cp "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$INSTALL_PATH/Contents/MacOS/$APP_NAME"
    cp "$APP_BUNDLE/Contents/Info.plist" "$INSTALL_PATH/Contents/Info.plist"
    cp "$APP_BUNDLE/Contents/Resources/AppIcon.icns" "$INSTALL_PATH/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi

codesign --sign - --force --deep "$INSTALL_PATH"
open "$INSTALL_PATH"

echo "✓ Installed and launched"
