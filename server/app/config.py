from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SERVER_ROOT = PROJECT_ROOT / "server"
CONFIG_ROOT = PROJECT_ROOT / "config"
DEFAULT_CONFIG_FILE = CONFIG_ROOT / "proxy.config.json"
DEFAULT_LOG_FILE = SERVER_ROOT / "server.log"
DEFAULT_SYSTEM_PROMPT_FILE = SERVER_ROOT / "system_prompt.txt"


@dataclass(slots=True)
class Settings:
    bind_host: str
    port: int
    openrouter_api_key: str | None
    openrouter_model: str
    openrouter_base_url: str
    request_timeout_seconds: float
    log_level: str
    log_file: Path
    system_prompt_file: Path
    disable_reasoning: bool

    @property
    def openrouter_configured(self) -> bool:
        return bool(self.openrouter_api_key)


def _load_json_config(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _resolve_path(value: str | Path, *, base: Path) -> Path:
    path = value if isinstance(value, Path) else Path(value)
    if path.is_absolute():
        return path
    return (base / path).resolve()


def load_settings(config_path: Path | None = None) -> Settings:
    config_path = config_path or DEFAULT_CONFIG_FILE
    file_config = _load_json_config(config_path)

    server_cfg = file_config.get("server", {})
    openrouter_cfg = file_config.get("openrouter", {})
    logging_cfg = file_config.get("logging", {})

    bind_host = os.getenv("BIND_HOST", server_cfg.get("bind_host", "0.0.0.0"))
    port = int(os.getenv("PROXY_PORT", server_cfg.get("port", 8080)))
    timeout = float(
        os.getenv(
            "REQUEST_TIMEOUT_SECONDS",
            openrouter_cfg.get("request_timeout_seconds", 15),
        )
    )
    log_level = os.getenv("LOG_LEVEL", logging_cfg.get("level", "INFO"))
    log_file = _resolve_path(
        os.getenv("SERVER_LOG_FILE", logging_cfg.get("file", str(DEFAULT_LOG_FILE))),
        base=PROJECT_ROOT,
    )
    system_prompt_file = _resolve_path(
        os.getenv("SYSTEM_PROMPT_FILE", str(server_cfg.get("system_prompt_file", DEFAULT_SYSTEM_PROMPT_FILE))),
        base=PROJECT_ROOT,
    )

    return Settings(
        bind_host=bind_host,
        port=port,
        openrouter_api_key=os.getenv("OPENROUTER_API_KEY"),
        openrouter_model=os.getenv("OPENROUTER_MODEL", openrouter_cfg.get("model", "moonshotai/kimi-k2.5")),
        openrouter_base_url=os.getenv(
            "OPENROUTER_BASE_URL",
            openrouter_cfg.get("base_url", "https://openrouter.ai/api/v1/chat/completions"),
        ),
        request_timeout_seconds=timeout,
        log_level=log_level,
        log_file=log_file,
        system_prompt_file=system_prompt_file,
        disable_reasoning=str(os.getenv("DISABLE_REASONING", str(openrouter_cfg.get("disable_reasoning", True)))).lower()
        in {"1", "true", "yes", "on"},
    )
