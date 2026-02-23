from __future__ import annotations

import asyncio
from dataclasses import dataclass
from pathlib import Path
from typing import Awaitable, Callable

from .error_policy import (
    OpenRouterEmptyResponseError,
    OpenRouterError,
    OpenRouterHTTPError,
    OpenRouterTimeoutError,
    is_billing_related_error,
)
from .models import TranslateRequest
from .prompt_builder import build_messages

DEFAULT_SYSTEM_PROMPT = (
    "You are a translation engine for a messaging app. Translate accurately and naturally. "
    "Return only the translated text with no explanations."
)

AsyncSleep = Callable[[float], Awaitable[None]]


@dataclass(slots=True)
class TranslationOutcome:
    translated_text: str
    original_text: str
    direction: str
    translation_failed: bool
    used_fallback: bool
    success: bool
    failure_reason: str | None = None
    attempts: int = 0


class Translator:
    def __init__(
        self,
        *,
        openrouter_client,
        system_prompt_file: Path,
        logger,
        sleep_func: AsyncSleep = asyncio.sleep,
    ) -> None:
        self._openrouter_client = openrouter_client
        self._system_prompt_file = system_prompt_file
        self._logger = logger
        self._sleep = sleep_func

    async def translate(self, request: TranslateRequest, request_id: str) -> TranslationOutcome:
        original_text = request.text
        if original_text == "":
            return TranslationOutcome(
                translated_text=original_text,
                original_text=original_text,
                direction=request.direction,
                translation_failed=False,
                used_fallback=False,
                success=True,
                failure_reason=None,
                attempts=0,
            )

        system_prompt = self._read_system_prompt()
        messages = build_messages(system_prompt, request)

        empty_backoffs = [1, 2, 4, 8, 16]
        empty_retry_idx = 0
        timeout_retries = 0
        billing_retries = 0
        rate_limit_retries = 0
        attempts = 0

        while True:
            attempts += 1
            try:
                translated = await self._openrouter_client.translate(messages=messages, request_id=request_id)
                self._logger.info(
                    "request_id=%s outcome=success direction=%s attempts=%s",
                    request_id,
                    request.direction,
                    attempts,
                )
                return TranslationOutcome(
                    translated_text=translated,
                    original_text=original_text,
                    direction=request.direction,
                    translation_failed=False,
                    used_fallback=False,
                    success=True,
                    attempts=attempts,
                )
            except OpenRouterEmptyResponseError as exc:
                if empty_retry_idx < len(empty_backoffs):
                    delay = float(empty_backoffs[empty_retry_idx])
                    empty_retry_idx += 1
                    self._logger.warning(
                        "request_id=%s outcome=retry_empty attempt=%s delay=%ss error=%s",
                        request_id,
                        attempts,
                        delay,
                        exc,
                    )
                    await self._sleep(delay)
                    continue
                return self._fallback(request, request_id, "empty_response", attempts)
            except OpenRouterTimeoutError as exc:
                if timeout_retries < 3:
                    timeout_retries += 1
                    self._logger.warning(
                        "request_id=%s outcome=retry_timeout attempt=%s retry=%s error=%s",
                        request_id,
                        attempts,
                        timeout_retries,
                        exc,
                    )
                    await self._sleep(1)
                    continue
                return self._fallback(request, request_id, "timeout", attempts)
            except OpenRouterHTTPError as exc:
                if exc.status_code == 429:
                    if rate_limit_retries < 3:
                        rate_limit_retries += 1
                        delay = exc.retry_after_seconds if exc.retry_after_seconds is not None else 2.0
                        self._logger.warning(
                            "request_id=%s outcome=retry_rate_limit attempt=%s retry=%s delay=%ss status=%s",
                            request_id,
                            attempts,
                            rate_limit_retries,
                            delay,
                            exc.status_code,
                        )
                        await self._sleep(delay)
                        continue
                    return self._fallback(request, request_id, "rate_limit", attempts)

                if is_billing_related_error(exc):
                    if billing_retries < 3:
                        billing_retries += 1
                        self._logger.warning(
                            "request_id=%s outcome=retry_billing attempt=%s retry=%s status=%s",
                            request_id,
                            attempts,
                            billing_retries,
                            exc.status_code,
                        )
                        await self._sleep(5)
                        continue
                    return self._fallback(request, request_id, "billing", attempts)

                return self._fallback(request, request_id, f"http_{exc.status_code}", attempts)
            except OpenRouterError:
                return self._fallback(request, request_id, "openrouter_error", attempts)
            except Exception:
                self._logger.exception("request_id=%s outcome=unexpected_exception", request_id)
                return self._fallback(request, request_id, "unexpected_error", attempts)

    def _read_system_prompt(self) -> str:
        try:
            text = self._system_prompt_file.read_text(encoding="utf-8").strip()
            if text:
                return text
        except Exception as exc:
            self._logger.exception("Failed to read system prompt file %s: %s", self._system_prompt_file, exc)
        return DEFAULT_SYSTEM_PROMPT

    def _fallback(self, request: TranslateRequest, request_id: str, reason: str, attempts: int) -> TranslationOutcome:
        self._logger.error(
            "request_id=%s outcome=fallback reason=%s direction=%s attempts=%s",
            request_id,
            reason,
            request.direction,
            attempts,
        )
        return TranslationOutcome(
            translated_text=request.text,
            original_text=request.text,
            direction=request.direction,
            translation_failed=True,
            used_fallback=True,
            success=False,
            failure_reason=reason,
            attempts=attempts,
        )
