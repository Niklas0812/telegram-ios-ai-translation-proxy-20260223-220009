# Telegram-iOS Hook Points (To Verify Against Upstream Revision)

This document tracks the intended minimal hook points for the AI translation interceptor.

## Outgoing translation (before send)

Target area (expected):
- `submodules/TelegramCore/...` send pipeline (`enqueueMessages`) call sites
- Chat input send action in `TelegramUI` (preferred interception point for UI feedback and async translation)

Planned behavior:
- Intercept only text messages
- Skip secret chats and non-text content
- Translate via `AITranslationService` before passing text to `enqueueMessages`
- Fallback to original text on any proxy/server failure

## Incoming translation (display only)

Target area (expected):
- Text message rendering path in `TelegramUI` chat message nodes/items

Planned behavior:
- Do not alter Postbox-stored message text
- Translate asynchronously for display only
- Show translated text + AI indicator
- Provide "Show Original" action in long-press menu

## Settings integration

Target area (expected):
- Telegram Settings UI list construction in `TelegramUI/Sources/Settings/`

Planned additions:
- `AI Translation` settings entry
- Global toggles
- Proxy URL + Test Connection
- Dev Settings subpage
