from __future__ import annotations

from pathlib import Path

import pytest

from app.models import TranslateRequest
from app.translator import Translator


class RecordingClient:
    def __init__(self):
        self.calls = []

    async def translate(self, *, messages, request_id):
        self.calls.append(messages)
        return "translated"


@pytest.mark.asyncio
async def test_system_prompt_is_reloaded_per_request(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt A", encoding="utf-8")

    client = RecordingClient()
    translator = Translator(
        openrouter_client=client,
        system_prompt_file=prompt_file,
        logger=__import__("logging").getLogger("test"),
    )

    req = TranslateRequest(text="Hello", direction="outgoing")
    await translator.translate(req, request_id="1")
    prompt_file.write_text("Prompt B", encoding="utf-8")
    await translator.translate(req, request_id="2")

    assert client.calls[0][0]["content"] == "Prompt A"
    assert client.calls[1][0]["content"] == "Prompt B"
