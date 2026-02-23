from __future__ import annotations

from pathlib import Path

import pytest

from app.error_policy import OpenRouterTimeoutError
from app.models import TranslateRequest
from app.translator import Translator


class TimeoutClient:
    def __init__(self):
        self.call_count = 0

    async def translate(self, *, messages, request_id):
        self.call_count += 1
        raise OpenRouterTimeoutError("timeout")


@pytest.mark.asyncio
async def test_timeout_retries_then_falls_back(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    client = TimeoutClient()
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
        TranslateRequest(text="Hello", direction="outgoing"),
        request_id="timeout",
    )

    assert outcome.translation_failed is True
    assert outcome.translated_text == "Hello"
    assert outcome.failure_reason == "timeout"
    assert client.call_count == 4  # initial + 3 retries
    assert sleeps == [1, 1, 1]
