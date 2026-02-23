#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-vendor/Telegram-iOS}"
REPO_URL="${TELEGRAM_IOS_REPO:-https://github.com/TelegramMessenger/Telegram-iOS.git}"
REPO_REF="${TELEGRAM_IOS_REF:-master}"

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "Telegram-iOS already cloned at $TARGET_DIR"
  exit 0
fi

mkdir -p "$(dirname "$TARGET_DIR")"
git clone --recursive --branch "$REPO_REF" "$REPO_URL" "$TARGET_DIR"
