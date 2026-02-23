from __future__ import annotations

from .models import TranslateRequest


def _language_pair(direction: str) -> tuple[str, str]:
    if direction == "outgoing":
        return ("English", "German")
    return ("German", "English")


def build_messages(system_prompt: str, request: TranslateRequest) -> list[dict[str, str]]:
    source_lang, target_lang = _language_pair(request.direction)

    context_block = "(none)"
    if request.context:
        lines = ["Conversation context (for understanding only; DO NOT translate these lines):"]
        for item in request.context:
            lines.append(f"- {item.role}: {item.text}")
        context_block = "\n".join(lines)

    user_prompt = (
        "You are translating a chat message.\n"
        f"Direction: {request.direction} ({source_lang} -> {target_lang})\n"
        "Rules:\n"
        "1. Translate ONLY the CURRENT_TEXT below.\n"
        "2. Use context only for disambiguation and tone.\n"
        "3. Return only the translated text with no commentary, no quotes, no labels.\n"
        "4. Preserve meaning, intent, and casual chat tone.\n"
        f"5. Target language: {target_lang}.\n\n"
        f"{context_block}\n\n"
        "CURRENT_TEXT:\n"
        f"{request.text}"
    )

    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
