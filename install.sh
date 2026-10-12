#!/bin/bash
set -e

# Coucou + Google Antigravity Automated Installer for macOS
# Repository: https://github.com/ruslanower/coucou-antigravity

echo "========================================================"
echo "    Coucou + Antigravity Auto-Installer for macOS      "
echo "========================================================"

if [ "$(uname)" != "Darwin" ]; then
    echo "❌ Помилка: Цей скрипт призначений тільки для macOS."
    exit 1
fi

SUPPORT_DIR="$HOME/Library/Application Support/NotchBuddy"
CONFIG_DIR="$HOME/.gemini/config"
APP_PATH="/Applications/Coucou.app"
COUCOU_VERSION="v0.3.0"
DOWNLOAD_URL="https://github.com/Louis-CFM/coucou/releases/download/${COUCOU_VERSION}/Coucou.zip"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# 1. Завантаження та встановлення Coucou.app
if [ ! -d "$APP_PATH" ] || [ "$1" == "--force" ]; then
    echo "⬇️  Завантаження Coucou (${COUCOU_VERSION})..."
    TMP_DIR=$(mktemp -d)
    curl -fL -o "${TMP_DIR}/Coucou.zip" "$DOWNLOAD_URL"
    echo "📦 Розпакування до /Applications..."
    unzip -q -o "${TMP_DIR}/Coucou.zip" -d "${TMP_DIR}/extracted"
    rm -rf "$APP_PATH"
    cp -R "${TMP_DIR}/extracted/Coucou.app" /Applications/
    rm -rf "$TMP_DIR"
    echo "✅ Coucou.app встановлено в /Applications"
else
    echo "✅ Coucou.app вже встановлено в /Applications"
fi

# Зняття карантину Gatekeeper
xattr -cr "$APP_PATH" 2>/dev/null || true

# 2. Налаштування директорії підтримки
echo "⚙️  Налаштування мосту NotchBuddy..."
mkdir -p "$SUPPORT_DIR"
chmod 700 "$SUPPORT_DIR"

if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/nb-hook.py" ]; then
    cp "${SCRIPT_DIR}/nb-hook" "$SUPPORT_DIR/nb-hook"
    cp "${SCRIPT_DIR}/nb-hook.py" "$SUPPORT_DIR/nb-hook.py"
else
    echo "🌐 Завантаження оновлених скриптів релея з GitHub..."
    REPO_RAW="https://raw.githubusercontent.com/ruslanower/coucou-antigravity/main"
    curl -sSL -o "$SUPPORT_DIR/nb-hook" "${REPO_RAW}/nb-hook"
    curl -sSL -o "$SUPPORT_DIR/nb-hook.py" "${REPO_RAW}/nb-hook.py"
fi

chmod +x "$SUPPORT_DIR/nb-hook" "$SUPPORT_DIR/nb-hook.py"

# 3. Налаштування параметрів Coucou (активація карток у чілці та віджету Antigravity)
echo "🛠  Активація віджета Antigravity та показу карток у чілці..."
defaults write fr.louisraille.NotchBuddy terminalCardsEnabled -bool true
defaults write fr.louisraille.NotchBuddy mainPill -string "agent_antigravity"

python3 - << 'PYEOF'
import plistlib, os, json

p = os.path.expanduser("~/Library/Preferences/fr.louisraille.NotchBuddy.plist")
if os.path.exists(p):
    try:
        with open(p, "rb") as f:
            pl = plistlib.load(f)
        raw = pl.get("activeIntegrations", b"[]")
        if isinstance(raw, bytes):
            items = json.loads(raw.decode("utf-8"))
        else:
            items = json.loads(raw)
        if "agent_antigravity" not in items:
            items.append("agent_antigravity")
            pl["activeIntegrations"] = json.dumps(items).encode("utf-8")
            with open(p, "wb") as f:
                plistlib.dump(pl, f)
    except Exception as e:
        pass
PYEOF

# 4. Налаштування хуків Antigravity (~/.gemini/config/hooks.json)
echo "🔗 Налаштування хуків Antigravity..."
mkdir -p "$CONFIG_DIR"
HOOKS_FILE="$CONFIG_DIR/hooks.json"

if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/hooks.json" ]; then
    cp "${SCRIPT_DIR}/hooks.json" "$HOOKS_FILE"
else
    curl -sSL -o "$HOOKS_FILE" "${REPO_RAW}/hooks.json"
fi

# 5. Перезапуск Coucou
echo "🚀 Запуск Coucou..."
pkill -x Coucou 2>/dev/null || true
sleep 1
open -a "/Applications/Coucou.app"

echo "🔐 Відкриття системних налаштувань Спеціальних можливостей (Accessibility)..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "🎉 УСТАНОВКА УСПІШНО ЗАВЕРШЕНА!"
echo "--------------------------------------------------------"
echo "1. У відкритому вікні 'Спеціальні можливості' увімкніть перемикач навпроти Coucou."
echo "2. Mochi з'явився у верхній панелі / чілці."
echo "3. Antigravity тепер дублює всі свої дії, питання та запити дозволів у чілку!"
echo "--------------------------------------------------------"
