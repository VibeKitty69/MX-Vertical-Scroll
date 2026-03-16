#!/bin/bash
set -e

APP_NAME="MXVerticalScroller"
DISPLAY_NAME="MX Vertical Scroller"
BINARY="$APP_NAME"
APP_BUNDLE="$DISPLAY_NAME.app"

echo "Building $DISPLAY_NAME..."

# Generate app icon
echo "Generating icon..."
swift make_icon.swift

# Compile all Swift sources
swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/SpeedSliderView.swift \
    Sources/ScrollInterceptor.swift \
    -framework AppKit \
    -framework CoreGraphics \
    -framework ServiceManagement \
    -target arm64-apple-macos12 \
    -o "${BINARY}_arm64"

swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/SpeedSliderView.swift \
    Sources/ScrollInterceptor.swift \
    -framework AppKit \
    -framework CoreGraphics \
    -framework ServiceManagement \
    -target x86_64-apple-macos12 \
    -o "${BINARY}_x86"

# Merge into a universal binary
lipo -create -output "$BINARY" "${BINARY}_arm64" "${BINARY}_x86"
rm "${BINARY}_arm64" "${BINARY}_x86"

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary, plist, and icon
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$BINARY"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Clean up loose binary
rm "$BINARY"

echo ""
echo "✓ Built: $APP_BUNDLE"
echo ""
echo "Next steps:"
echo "  1. Move it to Applications:  mv \"$APP_BUNDLE\" /Applications/"
echo "  2. Launch it:                open \"/Applications/$APP_BUNDLE\""
echo "  3. Grant Accessibility access when prompted"
echo ""
echo "Or just run it from here:    open $APP_BUNDLE"
