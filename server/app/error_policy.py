from __future__ import annotations

from dataclasses import dataclass
from typing import Any


class OpenRouterError(Exception):
    """Base exception for upstream OpenRouter failures."""


@dataclass(slots=True)
class OpenRouterHTTPError(OpenRouterError):
    status_code: int
    message: str
    body: Any | None = None
    retry_after_seconds: float | None = None

    def __str__(self) -> str:
        return f"OpenRouterHTTPError(status={self.status_code}, message={self.message})"


class OpenRouterTimeoutError(OpenRouterError):
    pass


class OpenRouterEmptyResponseError(OpenRouterError):
    pass


class OpenRouterMalformedResponseError(OpenRouterError):
    pass


def is_billing_related_error(error: OpenRouterHTTPError) -> bool:
    if error.status_code == 402:
        return True
    haystack = (error.message or "").lower()
    return any(token in haystack for token in ("billing", "payment", "insufficient", "balance", "credits"))


def looks_like_upstream_error_text(text: str) -> bool:
    normalized = text.strip().lower()
    if not normalized:
        return True
    suspicious_prefixes = (
        "error:",
        "openrouter",
        "payment required",
        "insufficient balance",
        "rate limit",
        "unauthorized",
    )
    if any(normalized.startswith(prefix) for prefix in suspicious_prefixes):
        return True
    suspicious_fragments = (
        "insufficient balance",
        "payment required",
        "api key",
        "quota exceeded",
        "retry-after",
        "status code",
    )
    return any(fragment in normalized for fragment in suspicious_fragments)
