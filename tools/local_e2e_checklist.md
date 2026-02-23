# Local End-to-End Checklist

## Proxy

- [ ] `GET /health` returns `status=ok`
- [ ] `GET /stats` updates after translation requests
- [ ] EN->DE and DE->EN smoke translations succeed
- [ ] Billing/timeout/rate-limit fallbacks return original text
- [ ] `system_prompt.txt` change is reflected on next request

## Telegram build pipeline

- [ ] Overlay scripts clone and copy `AITranslation` files
- [ ] GitHub Actions `build-ipa.yml` completes on `macos-14`
- [ ] IPA artifact downloads locally
- [ ] IPA re-signs in Sideloadly and installs on iPhone

## App behavior (after hook patches exist)

- [ ] Outgoing translation replaces sent text
- [ ] Incoming translation only affects display text
- [ ] Global/per-chat/per-direction toggles work
- [ ] Proxy down -> graceful fallback to original text
