#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <telegram-ios-dir>"
  exit 1
fi

TG_DIR="$1"
: "${TELEGRAM_API_ID:=TELEGRAM_API_ID_PLACEHOLDER}"
: "${TELEGRAM_API_HASH:=TELEGRAM_API_HASH_PLACEHOLDER}"
: "${TELEGRAM_BUNDLE_ID:=com.aitranslate.messenger}"
: "${TELEGRAM_APP_NAME:=TranslateGram}"

OUT_DIR="$TG_DIR/build-inputs"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/telegram-ai-translation.env" <<EOCFG
TELEGRAM_API_ID=$TELEGRAM_API_ID
TELEGRAM_API_HASH=$TELEGRAM_API_HASH
TELEGRAM_BUNDLE_ID=$TELEGRAM_BUNDLE_ID
TELEGRAM_APP_NAME=$TELEGRAM_APP_NAME
EOCFG

echo "Wrote build input placeholders to $OUT_DIR/telegram-ai-translation.env"
echo "NOTE: Telegram-iOS upstream build config wiring differs by revision; update this script after hook-point verification."
