#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="SnapMaster"
BUNDLE_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Đang biên dịch SnapMaster với Swift Release/Debug..."
cd "$PROJECT_DIR"
swift build -c release

# Tìm file thực thi vừa biên dịch
EXECUTABLE_PATH=$(find .build -name "$APP_NAME" -type f -perm +111 | grep -i "release" | head -n 1)

if [ -z "$EXECUTABLE_PATH" ]; then
    EXECUTABLE_PATH=$(find .build -name "$APP_NAME" -type f -perm +111 | head -n 1)
fi

echo "📦 Tạo cấu trúc macOS App Bundle tại: $BUNDLE_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy file binary
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Tạo Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>vi</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.snapmaster.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>SnapMaster cần quyền ghi màn hình để chụp ảnh và quay video màn hình của bạn.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>SnapMaster cần quyền sử dụng micro để ghi lại âm thanh khi quay video.</string>
</dict>
</plist>
EOF

echo "🔏 Đang ký chứng thực mã nguồn (Code Sign) với định danh com.snapmaster.app..."
codesign --force --deep --sign - -r='designated => identifier "com.snapmaster.app"' "$BUNDLE_DIR"

echo "✅ Đã đóng gói thành công $APP_NAME.app!"
echo "📍 Vị trí: $BUNDLE_DIR"
