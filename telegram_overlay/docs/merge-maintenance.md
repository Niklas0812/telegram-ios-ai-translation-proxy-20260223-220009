# Upstream Merge Maintenance Strategy

## Approach

- Keep this repo as an overlay + patch set, not a vendored Telegram-iOS fork.
- Copy standalone files from `telegram_overlay/files/` into upstream clone.
- Keep upstream modifications in a numbered patch series under `telegram_overlay/patches/`.

## Update procedure

1. Clone newer Telegram-iOS upstream revision.
2. Re-apply overlay files.
3. Rebase/rebuild patch series in order.
4. Re-run IPA CI build and proxy integration smoke tests.

## Patch grouping

- `0001`: Add `AITranslation` submodule and Bazel wiring
- `0002`: Outgoing send interception
- `0003`: Incoming display translation wiring
- `0004`: Settings screens / persistence wiring
- `0005`: Chat header toggle + translated indicators / show original UX
