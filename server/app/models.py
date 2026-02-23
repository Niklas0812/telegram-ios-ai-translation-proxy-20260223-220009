from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ContextMessage(BaseModel):
    role: Literal["me", "them"]
    text: str


class TranslateRequest(BaseModel):
    text: str
    direction: Literal["incoming", "outgoing"]
    chat_id: str | None = None
    context: list[ContextMessage] = Field(default_factory=list)

    @field_validator("context")
    @classmethod
    def validate_context_size(cls, value: list[ContextMessage]) -> list[ContextMessage]:
        if len(value) > 100:
            raise ValueError("context may contain at most 100 items")
        return value


class TranslateResponse(BaseModel):
    translated_text: str
    original_text: str
    direction: Literal["incoming", "outgoing"]
    translation_failed: bool


class HealthResponse(BaseModel):
    status: Literal["ok"]
    uptime_seconds: float
    last_successful_translation_at: str | None
    openrouter_configured: bool


class StatsResponse(BaseModel):
    total_requests: int
    successful_translations: int
    fallback_count: int
    success_rate: float
    average_response_time_ms: float
    inflight_requests: int
