from __future__ import annotations

import json
from typing import Any

import httpx

from .config import Settings
from .error_policy import (
    OpenRouterEmptyResponseError,
    OpenRouterHTTPError,
    OpenRouterMalformedResponseError,
    OpenRouterTimeoutError,
    looks_like_upstream_error_text,
)


class OpenRouterClient:
    def __init__(self, settings: Settings, logger, http_client: httpx.AsyncClient | None = None) -> None:
        self._settings = settings
        self._logger = logger
        self._http_client = http_client or httpx.AsyncClient(timeout=settings.request_timeout_seconds)
        self._owns_client = http_client is None

    async def close(self) -> None:
        if self._owns_client:
            await self._http_client.aclose()

    async def translate(self, *, messages: list[dict[str, Any]], request_id: str) -> str:
        if not self._settings.openrouter_api_key:
            raise OpenRouterHTTPError(status_code=401, message="OpenRouter API key missing")

        headers = {
            "Authorization": f"Bearer {self._settings.openrouter_api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://localhost",
            "X-Title": "Telegram AI Translation Proxy",
        }
        payload: dict[str, Any] = {
            "model": self._settings.openrouter_model,
            "messages": messages,
            "stream": False,
            "temperature": 0.2,
        }
        if self._settings.disable_reasoning:
            payload["reasoning"] = {"enabled": False}

        try:
            response = await self._http_client.post(self._settings.openrouter_base_url, headers=headers, json=payload)
        except httpx.TimeoutException as exc:
            raise OpenRouterTimeoutError("OpenRouter request timed out") from exc
        except httpx.HTTPError as exc:
            raise OpenRouterHTTPError(status_code=0, message=str(exc)) from exc

        if response.status_code >= 400:
            retry_after = _parse_retry_after(response.headers.get("Retry-After"))
            body_text = response.text
            message = _extract_error_message(body_text)
            raise OpenRouterHTTPError(
                status_code=response.status_code,
                message=message,
                body=body_text,
                retry_after_seconds=retry_after,
            )

        try:
            data = response.json()
        except json.JSONDecodeError as exc:
            raise OpenRouterMalformedResponseError("OpenRouter returned invalid JSON") from exc

        if isinstance(data, dict) and data.get("error"):
            message = _extract_error_message(data)
            raise OpenRouterHTTPError(status_code=response.status_code, message=message, body=data)

        content = _extract_message_content(data)
        if content is None or not content.strip() or looks_like_upstream_error_text(content):
            raise OpenRouterEmptyResponseError("OpenRouter returned empty or suspicious content")

        return content.strip()


def _parse_retry_after(value: str | None) -> float | None:
    if not value:
        return None
    try:
        parsed = float(value)
    except ValueError:
        return None
    if parsed < 0:
        return None
    return parsed


def _extract_error_message(body: Any) -> str:
    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict):
            msg = error.get("message") or error.get("code")
            if msg:
                return str(msg)
        if isinstance(error, str):
            return error
        return str(body)

    if isinstance(body, str):
        try:
            parsed = json.loads(body)
        except Exception:
            return body[:500]
        return _extract_error_message(parsed)

    return str(body)


def _extract_message_content(data: Any) -> str | None:
    if not isinstance(data, dict):
        return None
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        return None

    first = choices[0]
    if not isinstance(first, dict):
        return None
    message = first.get("message")
    if not isinstance(message, dict):
        return None
    content = message.get("content")

    if isinstance(content, str):
        return content
    if isinstance(content, list):
        chunks: list[str] = []
        for part in content:
            if isinstance(part, dict) and isinstance(part.get("text"), str):
                chunks.append(part["text"])
            elif isinstance(part, str):
                chunks.append(part)
        return "".join(chunks) if chunks else None
    return None
