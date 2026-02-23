from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass(slots=True)
class RequestHandle:
    started_at_perf: float


class StatsTracker:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._boot_wall = datetime.now(timezone.utc)
        self._boot_perf = time.perf_counter()
        self._total_requests = 0
        self._successful_translations = 0
        self._fallback_count = 0
        self._total_response_time_ms = 0.0
        self._inflight_requests = 0
        self._last_successful_translation_at: datetime | None = None

    async def record_translate_request_start(self) -> RequestHandle:
        async with self._lock:
            self._total_requests += 1
            self._inflight_requests += 1
        return RequestHandle(started_at_perf=time.perf_counter())

    async def record_translate_request_end(self, handle: RequestHandle, *, success: bool, used_fallback: bool) -> None:
        elapsed_ms = (time.perf_counter() - handle.started_at_perf) * 1000.0
        async with self._lock:
            self._inflight_requests = max(0, self._inflight_requests - 1)
            self._total_response_time_ms += elapsed_ms
            if used_fallback:
                self._fallback_count += 1
            if success:
                self._successful_translations += 1
                self._last_successful_translation_at = datetime.now(timezone.utc)

    async def health_snapshot(self, openrouter_configured: bool) -> dict:
        async with self._lock:
            last_success = self._last_successful_translation_at.isoformat() if self._last_successful_translation_at else None
        return {
            "status": "ok",
            "uptime_seconds": round(time.perf_counter() - self._boot_perf, 3),
            "last_successful_translation_at": last_success,
            "openrouter_configured": openrouter_configured,
        }

    async def stats_snapshot(self) -> dict:
        async with self._lock:
            total = self._total_requests
            success = self._successful_translations
            fallback = self._fallback_count
            avg_ms = self._total_response_time_ms / total if total else 0.0
            inflight = self._inflight_requests
        return {
            "total_requests": total,
            "successful_translations": success,
            "fallback_count": fallback,
            "success_rate": (success / total) if total else 0.0,
            "average_response_time_ms": round(avg_ms, 3),
            "inflight_requests": inflight,
        }
