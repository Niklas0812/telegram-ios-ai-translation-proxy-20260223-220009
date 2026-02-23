#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <telegram-ios-dir>"
  exit 1
fi

TG_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILES_DIR="$OVERLAY_ROOT/files"
PATCH_DIR="$OVERLAY_ROOT/patches"
APPLY_AI_PATCHES="${APPLY_AI_PATCHES:-0}"

if ! git -C "$TG_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a Telegram-iOS git checkout: $TG_DIR"
  exit 1
fi

if [[ -d "$FILES_DIR" ]]; then
  rsync -a "$FILES_DIR/" "$TG_DIR/"
  echo "Overlay files copied into $TG_DIR"
fi

if [[ "$APPLY_AI_PATCHES" != "1" ]]; then
  echo "Skipping AI patch application (set APPLY_AI_PATCHES=1 to apply patch series)"
  exit 0
fi

shopt -s nullglob
for patch in "$PATCH_DIR"/*.patch; do
  if grep -q "PLACEHOLDER_PATCH" "$patch"; then
    echo "Skipping placeholder patch $(basename "$patch")"
    continue
  fi
  echo "Applying $(basename "$patch")"
  git -C "$TG_DIR" apply --whitespace=fix "$patch"
done
