#!/bin/bash
# ACode macOS 一键打包脚本
# 用法: ./build.sh [debug|release]

set -e

MODE="${1:-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR/ACode"
RESOURCES_DIR="$PKG_DIR/Resources"
BUILD_DIR="$PKG_DIR/.build/$MODE"
APP_NAME="ACode"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUNDLE_ID="com.acode.mac"
VERSION="1.0.0"
BUILD_NUMBER="1"

echo "⚙ 铸造圣言：开始构建 ACode macOS ($MODE)..."

# ─── Step 1: 解析 SPM 依赖 ───
echo "📦 Step 1: 解析 SPM 依赖..."
cd "$PKG_DIR"
swift package resolve

# ─── Step 2: 编译 ───
echo "🔨 Step 2: 编译 ($MODE)..."
if [ "$MODE" = "release" ]; then
    swift build -c release
else
    swift build
fi

# 验证产物存在
EXECUTABLE="$BUILD_DIR/$APP_NAME"
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ 编译产物不存在: $EXECUTABLE"
    exit 1
fi
echo "✅ 编译成功: $EXECUTABLE"

# ─── Step 3: 组装 .app Bundle ───
echo "📱 Step 3: 组装 .app Bundle..."

# 清理旧 bundle
rm -rf "$APP_BUNDLE"

# 创建 .app 目录结构
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 复制可执行文件
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 复制 Info.plist
if [ -f "$RESOURCES_DIR/Info.plist" ]; then
    cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
    echo "  ✅ Info.plist"
else
    # 生成默认 Info.plist
    cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 ACode. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF
    echo "  ✅ Info.plist (generated)"
fi

# 复制应用图标
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  ✅ AppIcon.icns"
else
    echo "  ⚠️ AppIcon.icns 不存在，跳过图标"
fi

# 复制 Assets.xcassets（如果有 actool 编译的 Assets.car）
if [ -d "$RESOURCES_DIR/Assets.xcassets" ]; then
    # 使用 actool 编译 Asset Catalog
    if command -v actool &> /dev/null || [ -f "/Applications/Xcode.app/Contents/Developer/usr/bin/actool" ]; then
        ACTOOL="${ACTOOL:-/Applications/Xcode.app/Contents/Developer/usr/bin/actool}"
        if [ -f "$ACTOOL" ]; then
            "$ACTOOL" \
                --compile "$APP_BUNDLE/Contents/Resources" \
                --platform macosx \
                --minimum-deployment-target 14.0 \
                --app-icon AppIcon \
                --output-partial-info-plist /tmp/acode-assetcatalog-info.plist \
                "$RESOURCES_DIR/Assets.xcassets" 2>/dev/null && echo "  ✅ Assets.car (compiled)" || echo "  ⚠️ actool 编译失败，使用 .icns 回退"
        else
            echo "  ⚠️ actool 不可用，使用 .icns 回退"
        fi
    fi
fi

# 创建 PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
echo "  ✅ PkgInfo"

# ─── Step 4: 验证 ───
echo "🔍 Step 4: 验证 .app Bundle..."
echo "  Bundle: $APP_BUNDLE"
echo "  Size: $(du -sh "$APP_BUNDLE" | cut -f1)"

# 验证可执行
if [ -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "  ✅ 可执行文件: OK"
else
    echo "  ❌ 可执行文件: 不可执行"
    exit 1
fi

# 验证图标
if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    echo "  ✅ 应用图标: OK"
else
    echo "  ⚠️ 应用图标: 缺失"
fi

# 验证签名（如有）
codesign -v "$APP_BUNDLE" 2>/dev/null && echo "  ✅ 代码签名: OK" || echo "  ⚠️ 代码签名: 未签名（本地开发正常）"

echo ""
echo "⚙ 铸造完成！ACode.app 已生成: $APP_BUNDLE"
echo "  双击运行或拖入 /Applications 安装"
