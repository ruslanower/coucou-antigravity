#!/bin/bash
set -e

# ========================================================
#   «Rango» — Нативний помічник чілки для Antigravity
#   Репозиторій: https://github.com/ruslanower/rango
# ========================================================

echo "========================================================"
echo "    «Rango» — Встановлення нативного ШІ-помічника"
echo "========================================================"

if [ "$(uname)" != "Darwin" ]; then
    echo "❌ Помилка: Цей додаток призначений тільки для macOS."
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "❌ Помилка: Потрібні Xcode Command Line Tools. Встановіть через 'xcode-select --install'."
    exit 1
fi

SUPPORT_DIR="$HOME/Library/Application Support/NotchBuddy"
CONFIG_DIR="$HOME/.gemini/config"
APP_PATH="/Applications/Rango.app"
REPO_RAW="https://raw.githubusercontent.com/ruslanower/rango/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# 1. Збірка нативного Swift/SwiftUI додатку
echo "🛠  Збірка нативного Swift додатку «Rango»..."
BUILD_DIR="${SCRIPT_DIR}"

if [ ! -f "${BUILD_DIR}/Package.swift" ]; then
    TMP_SRC=$(mktemp -d)
    echo "🌐 Клонування вихідного коду з репозиторію..."
    git clone --depth=1 https://github.com/ruslanower/rango.git "$TMP_SRC"
    BUILD_DIR="$TMP_SRC"
fi

cd "$BUILD_DIR"
swift build -c release

# 2. Формування .app бандла
echo "📦 Створення бандла ${APP_PATH}..."
pkill -9 Rango 2>/dev/null || true
pkill -9 TukTuk 2>/dev/null || true
pkill -9 CoucouAntigravity 2>/dev/null || true
pkill -9 Coucou 2>/dev/null || true
rm -rf "$APP_PATH"
rm -rf "/Applications/TukTuk.app" 2>/dev/null || true
rm -rf "/Applications/CoucouAntigravity.app" 2>/dev/null || true
rm -rf "/Applications/Coucou.app" 2>/dev/null || true

mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"
cp "${BUILD_DIR}/.build/release/Rango" "${APP_PATH}/Contents/MacOS/"

if [ -d "${BUILD_DIR}/Resources" ]; then
    cp -r "${BUILD_DIR}/Resources/"* "${APP_PATH}/Contents/Resources/" 2>/dev/null || true
fi
if [ -f "${BUILD_DIR}/version.json" ]; then
    cp "${BUILD_DIR}/version.json" "${APP_PATH}/Contents/Resources/version.json" 2>/dev/null || true
fi

cat << 'EOF' > "${APP_PATH}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ruslanower.Rango</string>
    <key>CFBundleName</key>
    <string>Rango</string>
    <key>CFBundleDisplayName</key>
    <string>Rango</string>
    <key>CFBundleExecutable</key>
    <string>Rango</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>DTSDKName</key>
    <string>macosx27.0</string>
    <key>DTPlatformVersion</key>
    <string>27.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

xattr -cr "$APP_PATH" 2>/dev/null || true
codesign -s - --force --deep "$APP_PATH" 2>/dev/null || true

# 3. Налаштування хуків Antigravity
echo "⚙️  Встановлення скриптів мосту..."
mkdir -p "$SUPPORT_DIR"
chmod 700 "$SUPPORT_DIR"

if [ -f "${BUILD_DIR}/nb-hook" ]; then
    cp "${BUILD_DIR}/nb-hook" "$SUPPORT_DIR/nb-hook"
    cp "${BUILD_DIR}/nb-hook.py" "$SUPPORT_DIR/nb-hook.py"
else
    curl -sSL -o "$SUPPORT_DIR/nb-hook" "${REPO_RAW}/nb-hook"
    curl -sSL -o "$SUPPORT_DIR/nb-hook.py" "${REPO_RAW}/nb-hook.py"
fi
chmod +x "$SUPPORT_DIR/nb-hook" "$SUPPORT_DIR/nb-hook.py"

echo "🔗 Налаштування конфігурації хуків..."
mkdir -p "$CONFIG_DIR"
if [ -f "${BUILD_DIR}/hooks.json" ]; then
    cp "${BUILD_DIR}/hooks.json" "$CONFIG_DIR/hooks.json"
else
    curl -sSL -o "$CONFIG_DIR/hooks.json" "${REPO_RAW}/hooks.json"
fi

# 4. Запуск «Rango»
echo "🚀 Запуск «Rango»..."
nohup "$APP_PATH/Contents/MacOS/Rango" > /tmp/rango.log 2>&1 &
sleep 1

echo ""
echo "🎉 ВСТАНОВЛЕННЯ «RANGO» УСПІШНО ЗАВЕРШЕНО!"
echo "--------------------------------------------------------"
echo "1. «Rango» тепер живе у вашій чілці та панелі меню."
echo "2. Наведіть курсор на чілку — відкриється шторка з хамелеоном Rango."
echo "3. Rango динамічно аналізує всі ваші проєкти в Antigravity та генерує ідеї!"
echo "4. Клік по «Втілити ідею» миттєво відкриває Antigravity та починає роботу."
echo "--------------------------------------------------------"
