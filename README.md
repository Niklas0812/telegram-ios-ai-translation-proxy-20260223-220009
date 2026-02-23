# Telegram iOS AI Translation Proxy Fork (Scaffold)

This repository contains:

- A production-grade local translation proxy server (`server/`) for Telegram message translation via OpenRouter.
- A Telegram-iOS overlay/patch workflow (`telegram_overlay/`) for applying AI translation features to upstream Telegram-iOS.
- GitHub Actions workflows for proxy tests and Telegram IPA build scaffolding.

## Status

Implemented now:
- FastAPI proxy server with retry/fallback/error handling, stats, health, logging
- Hot-reloaded `server/system_prompt.txt`
- Automated proxy tests (mocked OpenRouter) with critical failure-mode coverage
- CI workflow scaffolding and Telegram overlay scripts
- `AITranslation` Swift module skeleton (to be patched into Telegram-iOS)

Not fully implemented yet:
- Telegram-iOS hook patches for outgoing/incoming interception and UI integration
- Verified IPA build from GitHub Actions against a real Telegram-iOS clone and credentials
- End-to-end app/device testing

## Quick Start (Proxy)

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r server/requirements.txt
cp .env.example .env  # optional; export vars manually
export OPENROUTER_API_KEY=...    # required for real translations
./server/run.sh
```

Proxy endpoints:
- `GET /health`
- `GET /stats`
- `POST /translate`

## Run Proxy Tests

```bash
.venv/bin/pytest -q server/tests
```

## Telegram-iOS Overlay Workflow (Scaffold)

```bash
./telegram_overlay/scripts/clone_telegram_ios.sh vendor/Telegram-iOS
./telegram_overlay/scripts/apply_overlay.sh vendor/Telegram-iOS
# ./telegram_overlay/scripts/configure_telegram_build.sh vendor/Telegram-iOS
# build commands depend on upstream Telegram-iOS state and credentials
```

## Cloudflare Tunnel (Local Dev)

See `tools/cloudflare_tunnel.md`.

## Security

Do not commit OpenRouter or Telegram credentials.
