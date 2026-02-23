from __future__ import annotations

import asyncio
from pathlib import Path

from fastapi.testclient import TestClient
import pytest

from app.config import Settings
from app.main import create_app
from app.models import TranslateRequest
from app.stats import StatsTracker
from app.translator import TranslationOutcome


class FakeTranslator:
    def __init__(self):
        self.counter = 0

    async def translate(self, request_body: TranslateRequest, request_id: str):
        self.counter += 1
        if request_body.text == "fail":
            return TranslationOutcome(
                translated_text=request_body.text,
                original_text=request_body.text,
                direction=request_body.direction,
                translation_failed=True,
                used_fallback=True,
                success=False,
                failure_reason="forced",
                attempts=1,
            )
        return TranslationOutcome(
            translated_text=f"x:{request_body.text}",
            original_text=request_body.text,
            direction=request_body.direction,
            translation_failed=False,
            used_fallback=False,
            success=True,
            attempts=1,
        )


class DummyOpenRouterClient:
    async def close(self):
        return None


def _settings(tmp_path: Path) -> Settings:
    prompt_file = tmp_path / "system_prompt.txt"
    prompt_file.write_text("Prompt", encoding="utf-8")
    return Settings(
        bind_host="0.0.0.0",
        port=8080,
        openrouter_api_key=None,
        openrouter_model="moonshotai/kimi-k2.5",
        openrouter_base_url="https://openrouter.ai/api/v1/chat/completions",
        request_timeout_seconds=15,
        log_level="INFO",
        log_file=tmp_path / "server.log",
        system_prompt_file=prompt_file,
        disable_reasoning=True,
    )


def test_health_and_stats_endpoints_track_translate_requests(tmp_path: Path):
    app = create_app(
        settings=_settings(tmp_path),
        stats=StatsTracker(),
        openrouter_client=DummyOpenRouterClient(),
        translator=FakeTranslator(),
    )

    with TestClient(app) as client:
        health_before = client.get("/health").json()
        assert health_before["status"] == "ok"
        assert health_before["last_successful_translation_at"] is None

        ok_resp = client.post("/translate", json={"text": "Hello", "direction": "outgoing"})
        assert ok_resp.status_code == 200
        assert ok_resp.json()["translated_text"] == "x:Hello"
        assert ok_resp.json()["translation_failed"] is False

        fail_resp = client.post("/translate", json={"text": "fail", "direction": "outgoing"})
        assert fail_resp.status_code == 200
        assert fail_resp.json()["translated_text"] == "fail"
        assert fail_resp.json()["translation_failed"] is True

        health_after = client.get("/health").json()
        assert health_after["last_successful_translation_at"] is not None

        stats = client.get("/stats").json()
        assert stats["total_requests"] == 2
        assert stats["successful_translations"] == 1
        assert stats["fallback_count"] == 1
        assert pytest.approx(stats["success_rate"], rel=1e-6) == 0.5


@pytest.mark.asyncio
async def test_stats_tracker_handles_concurrent_updates():
    tracker = StatsTracker()

    async def worker(success: bool, fallback: bool):
        handle = await tracker.record_translate_request_start()
        await asyncio.sleep(0)
        await tracker.record_translate_request_end(handle, success=success, used_fallback=fallback)

    await asyncio.gather(
        *(worker(True, False) for _ in range(5)),
        *(worker(False, True) for _ in range(3)),
    )

    snapshot = await tracker.stats_snapshot()
    assert snapshot["total_requests"] == 8
    assert snapshot["successful_translations"] == 5
    assert snapshot["fallback_count"] == 3
    assert snapshot["inflight_requests"] == 0
