from __future__ import annotations

from pathlib import Path

import pytest

from app.error_policy import OpenRouterEmptyResponseError
from app.models import TranslateRequest
from app.translator import Translator


class ScriptedClient:
    def __init__(self, responses):
        self._responses = list(responses)
        self.call_count = 0

    async def translate(self, *, messages, request_id):
        self.call_count += 1
        result = self._responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return result


@pytest.mark.asyncio
async def test_empty_response_retries_then_succeeds(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    client = ScriptedClient(
        [
            OpenRouterEmptyResponseError("empty 1"),
            OpenRouterEmptyResponseError("empty 2"),
            "Hallo!",
        ]
    )
    sleeps = []

    async def fake_sleep(delay: float):
        sleeps.append(delay)

    translator = Translator(
        openrouter_client=client,
        system_prompt_file=prompt_file,
        logger=__import__("logging").getLogger("test"),
        sleep_func=fake_sleep,
    )

    outcome = await translator.translate(
        TranslateRequest(text="Hello!", direction="outgoing"),
        request_id="empty-success",
    )

    assert outcome.translated_text == "Hallo!"
    assert outcome.translation_failed is False
    assert client.call_count == 3
    assert sleeps == [1.0, 2.0]


@pytest.mark.asyncio
async def test_empty_response_exhausts_retries_and_falls_back(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    client = ScriptedClient([OpenRouterEmptyResponseError("empty")] * 6)
    sleeps = []

    async def fake_sleep(delay: float):
        sleeps.append(delay)

    translator = Translator(
        openrouter_client=client,
        system_prompt_file=prompt_file,
        logger=__import__("logging").getLogger("test"),
        sleep_func=fake_sleep,
    )

    outcome = await translator.translate(
        TranslateRequest(text="Hello!", direction="outgoing"),
        request_id="empty-fail",
    )

    assert outcome.translated_text == "Hello!"
    assert outcome.translation_failed is True
    assert outcome.failure_reason == "empty_response"
    assert client.call_count == 6
    assert sleeps == [1.0, 2.0, 4.0, 8.0, 16.0]
