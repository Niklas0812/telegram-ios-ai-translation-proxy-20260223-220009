from __future__ import annotations

from pathlib import Path

import pytest

from app.error_policy import OpenRouterHTTPError
from app.models import TranslateRequest
from app.translator import Translator


class ScriptedRateClient:
    def __init__(self):
        self.calls = 0

    async def translate(self, *, messages, request_id):
        self.calls += 1
        if self.calls == 1:
            raise OpenRouterHTTPError(status_code=429, message="rate limited", retry_after_seconds=7)
        if self.calls == 2:
            raise OpenRouterHTTPError(status_code=429, message="rate limited", retry_after_seconds=1.5)
        return "Hello again"


@pytest.mark.asyncio
async def test_rate_limit_respects_retry_after(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    client = ScriptedRateClient()
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
        TranslateRequest(text="Hallo nochmal", direction="incoming"),
        request_id="rate",
    )

    assert outcome.translation_failed is False
    assert outcome.translated_text == "Hello again"
    assert client.calls == 3
    assert sleeps == [7, 1.5]
