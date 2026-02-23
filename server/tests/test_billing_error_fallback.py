from __future__ import annotations

from pathlib import Path

import pytest

from app.error_policy import OpenRouterHTTPError
from app.models import TranslateRequest
from app.translator import Translator


class BillingClient:
    def __init__(self):
        self.call_count = 0

    async def translate(self, *, messages, request_id):
        self.call_count += 1
        raise OpenRouterHTTPError(status_code=402, message="Payment Required: insufficient balance")


@pytest.mark.asyncio
async def test_billing_error_never_leaks_and_falls_back(tmp_path: Path):
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    client = BillingClient()
    sleeps = []

    async def fake_sleep(delay: float):
        sleeps.append(delay)

    translator = Translator(
        openrouter_client=client,
        system_prompt_file=prompt_file,
        logger=__import__("logging").getLogger("test"),
        sleep_func=fake_sleep,
    )

    original = "Sure, sending it now."
    outcome = await translator.translate(
        TranslateRequest(text=original, direction="outgoing"),
        request_id="billing",
    )

    assert outcome.translation_failed is True
    assert outcome.translated_text == original
    assert "insufficient balance" not in outcome.translated_text.lower()
    assert outcome.failure_reason == "billing"
    assert client.call_count == 4  # initial + 3 retries
    assert sleeps == [5, 5, 5]
