from __future__ import annotations

from pathlib import Path

import pytest

from app.models import TranslateRequest
from app.translator import Translator


class ScriptedClient:
    def __init__(self, responses):
        self._responses = list(responses)
        self.calls = []

    async def translate(self, *, messages, request_id):
        self.calls.append({"messages": messages, "request_id": request_id})
        result = self._responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return result


async def no_sleep(_: float) -> None:
    return None


@pytest.mark.asyncio
async def test_translate_success_with_context_and_hot_prompt_usage(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Custom system prompt", encoding="utf-8")

    client = ScriptedClient(["Klar, schicke es jetzt."])
    translator = Translator(
        openrouter_client=client,
        system_prompt_file=prompt_file,
        logger=__import__("logging").getLogger("test"),
        sleep_func=no_sleep,
    )

    req = TranslateRequest(
        text="Sure, sending it now.",
        direction="outgoing",
        context=[
            {"role": "them", "text": "Hast du das Dokument fertig?"},
            {"role": "me", "text": "Yes, I finished it yesterday."},
        ],
    )
    outcome = await translator.translate(req, request_id="req1")

    assert outcome.translated_text == "Klar, schicke es jetzt."
    assert outcome.translation_failed is False
    assert outcome.success is True
    assert len(client.calls) == 1
    sent_messages = client.calls[0]["messages"]
    assert sent_messages[0]["content"] == "Custom system prompt"
    assert "Translate ONLY the CURRENT_TEXT" in sent_messages[1]["content"]
    assert "Hast du das Dokument fertig?" in sent_messages[1]["content"]
