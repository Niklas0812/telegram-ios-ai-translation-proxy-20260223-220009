from __future__ import annotations

import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .config import Settings, load_settings
from .logging_setup import configure_logging
from .models import HealthResponse, StatsResponse, TranslateRequest, TranslateResponse
from .openrouter_client import OpenRouterClient
from .stats import StatsTracker
from .translator import Translator


def create_app(
    *,
    settings: Settings | None = None,
    logger=None,
    stats: StatsTracker | None = None,
    openrouter_client: OpenRouterClient | None = None,
    translator: Translator | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    logger = logger or configure_logging(settings.log_file, settings.log_level)
    stats = stats or StatsTracker()
    openrouter_client = openrouter_client or OpenRouterClient(settings, logger)
    translator = translator or Translator(
        openrouter_client=openrouter_client,
        system_prompt_file=settings.system_prompt_file,
        logger=logger,
    )

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        try:
            yield
        finally:
            await app.state.openrouter_client.close()

    app = FastAPI(title="AI Translation Proxy", version="1.0.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.logger = logger
    app.state.stats = stats
    app.state.openrouter_client = openrouter_client
    app.state.translator = translator

    @app.middleware("http")
    async def request_logging_middleware(request: Request, call_next):
        started = time.perf_counter()
        response = None
        try:
            response = await call_next(request)
            return response
        finally:
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            status_code = response.status_code if response is not None else 500
            logger.info(
                "http method=%s path=%s status=%s duration_ms=%.2f",
                request.method,
                request.url.path,
                status_code,
                elapsed_ms,
            )

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        payload = await app.state.stats.health_snapshot(app.state.settings.openrouter_configured)
        return HealthResponse(**payload)

    @app.get("/stats", response_model=StatsResponse)
    async def stats_endpoint() -> StatsResponse:
        payload = await app.state.stats.stats_snapshot()
        return StatsResponse(**payload)

    @app.post("/translate", response_model=TranslateResponse)
    async def translate(request_body: TranslateRequest) -> TranslateResponse:
        request_id = uuid.uuid4().hex[:12]
        handle = await app.state.stats.record_translate_request_start()
        outcome = await app.state.translator.translate(request_body, request_id=request_id)
        await app.state.stats.record_translate_request_end(
            handle,
            success=outcome.success,
            used_fallback=outcome.used_fallback,
        )
        return TranslateResponse(
            translated_text=outcome.translated_text,
            original_text=outcome.original_text,
            direction=outcome.direction,
            translation_failed=outcome.translation_failed,
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception("Unhandled exception on path %s", request.url.path)
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    return app


app = create_app()
