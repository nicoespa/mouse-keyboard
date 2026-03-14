#!/bin/bash
set -e

APP="MouseKeyboard.app"
CONTENTS="$APP/Contents"

echo "▸ Compilando..."
swift build -c release 2>&1

echo "▸ Empaquetando .app..."
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"

cp .build/release/MouseKeyboard "$CONTENTS/MacOS/"

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MouseKeyboard</string>
    <key>CFBundleIdentifier</key>
    <string>com.mousekeyboard.app</string>
    <key>CFBundleName</key>
    <string>MouseKeyboard</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MouseKeyboard necesita Accesibilidad para controlar el mouse con el teclado.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "✓ Listo: $APP"
echo ""
echo "  Abrir ahora:  open $APP"
echo "  Instalar:     mv $APP /Applications/"
