# Telegram-iOS Hook Points (To Verify Against Upstream Revision)

This document tracks the intended minimal hook points for the AI translation interceptor.

## Outgoing translation (before send) [implemented in patch 0002]

Target area (expected):
- `submodules/TelegramCore/...` send pipeline (`enqueueMessages`) call sites
- Chat input send action in `TelegramUI` (preferred interception point for UI feedback and async translation)

Planned behavior:
- Intercept only text messages
- Skip secret chats and non-text content
- Translate via `AITranslationService` before passing text to `enqueueMessages`
- Fallback to original text on any proxy/server failure

## Incoming translation (display only) [implemented in patch 0003, MVP]

Target area (verified):
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/BUILD` (Bazel dep on `AITranslation`)

Current MVP behavior:
- Do not alter Postbox-stored message text
- Translate asynchronously for display only via `AITranslationService` cache + `requestMessageUpdate`
- Preserve original text/entities when proxy falls back to original text
- No UI indicator / "Show Original" action yet (pending patch 0005)

## Settings integration

Target area (verified):
- Account settings screen item assembly:
  `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift`
- Settings routing / screen logic:
  `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift`
- Likely interaction plumbing (`PeerInfoInteraction`) in the same component sources

Planned additions:
- `AI Translation` settings entry
- Global toggles
- Proxy URL + Test Connection
- Dev Settings subpage

## Chat header toggle integration (pending patch 0005)

Target areas (verified):
- Navigation button creation in `submodules/TelegramUI/Sources/ChatController.swift`
- Navigation button action handling in `submodules/TelegramUI/Sources/Chat/ChatControllerNavigationButtonAction.swift`
- Right-bar-button application in `submodules/TelegramUI/Sources/Chat/UpdateChatPresentationInterfaceState.swift`
