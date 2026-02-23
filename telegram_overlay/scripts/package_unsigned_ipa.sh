#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <path-to-.app> <output-ipa>"
  exit 1
fi

APP_PATH="$1"
OUTPUT_IPA="$2"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/Payload"
cp -R "$APP_PATH" "$WORK_DIR/Payload/"
(
  cd "$WORK_DIR"
  /usr/bin/zip -qry "$OUTPUT_IPA" Payload
)

echo "Packaged IPA: $OUTPUT_IPA"
