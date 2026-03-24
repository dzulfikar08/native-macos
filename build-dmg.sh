#!/bin/bash
set -e

APP_NAME="OpenScreen"
VERSION="1.0.0"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"

echo "🔨 Building $APP_NAME..."

# Clean build
swift package clean

# Build release
echo "📦 Building release..."
swift build -c release --product OpenScreen

# Get the executable path
EXECUTABLE="$BUILD_DIR/$APP_NAME"
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed: executable not found at $EXECUTABLE"
    exit 1
fi

echo "✅ Build successful"

# Create app bundle
echo "📦 Creating app bundle..."

# Remove existing bundle if present
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.openscreen.native</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>OpenScreen needs access to your camera for webcam recording.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>OpenScreen needs access to your microphone for audio recording.</string>
    <key>NSScreenCaptureDescription</key>
    <string>OpenScreen needs screen recording permission to capture your screen or windows.</string>
</dict>
</plist>
EOF

# Copy Metal shader resources
if [ -d "Sources/native-macos/Editing/MetalShaders.metallib" ]; then
    cp -R Sources/native-macos/Editing/MetalShaders.metallib "$APP_BUNDLE/Contents/Resources/"
fi

if [ -d "Sources/native-macos/Timeline/TimelineShaders.metallib" ]; then
    cp -R Sources/native-macos/Timeline/TimelineShaders.metallib "$APP_BUNDLE/Contents/Resources/"
fi

echo "✅ App bundle created: $APP_BUNDLE"

# Create DMG
echo "💿 Creating DMG..."

# Remove existing DMG if present
rm -f "$DMG_NAME"

# Create temporary DMG folder
DMG_FOLDER="dmg_temp"
rm -rf "$DMG_FOLDER"
mkdir -p "$DMG_FOLDER"

# Copy app bundle to DMG folder
cp -R "$APP_BUNDLE" "$DMG_FOLDER/"

# Create Applications symlink
ln -s /Applications "$DMG_FOLDER/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_FOLDER" \
               -ov \
               -format UDBZ \
               "$DMG_NAME"

# Clean up
rm -rf "$DMG_FOLDER"

echo "✅ DMG created: $DMG_NAME"
echo ""
echo "📊 Build summary:"
echo "   App bundle: $APP_BUNDLE"
echo "   DMG: $DMG_NAME"
echo ""
echo "🚀 Ready to distribute!"
