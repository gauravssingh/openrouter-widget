# OpenRouter Widget

A lightweight, native macOS menu-bar utility for OpenRouter: see your available
credits, today/week/month spend, a 30-day spend chart, and top models — all at
a glance, straight from the menu bar.

> Screenshots: TODO

## What it shows

- **Available credits** (account balance) — the hero number, also optionally
  shown in the menu bar as `OR $42.18`
- **Spend for today / this week / this month**
- **30-day spend chart** (native Swift Charts)
- **Top models** by spend over the last 30 days
- **Last refresh status** — “Updated 2 min ago” (with a manual ↻ refresh;
  auto-refresh every 5 minutes by default, configurable)

## Requirements

- macOS 14 Sonoma or newer
- Xcode Command Line Tools (`swift` 5.9+)

## Build & test

```bash
swift build
swift test
```

## Run

Directly (development):

```bash
swift run
```

Or package a proper `.app` bundle (recommended for daily use — also enables
Launch at Login):

```bash
scripts/package-app.sh
open .build/OpenRouterWidget.app
```

The app runs as a menu-bar-only utility (`MenuBarExtra`): no Dock icon, no
main window. It keeps running when the popover closes; quit from the popover.

## API key setup

1. Click the menu-bar item → paste an OpenRouter API key → **Connect**.
2. The key is stored **only in the macOS Keychain** (`dev.gsingh.openrouter-widget`)
   — never in UserDefaults, files, or Git.
3. Replace or remove the key any time via **Settings → OpenRouter**.

### Permissions

| Data | Inference key | Management key |
| --- | --- | --- |
| Key usage / limits (`/api/v1/key`) | ✓ | ✓ |
| Account credits (`/api/v1/credits`) | ✗ (403) | ✓ |
| Spend history & top models (`/api/v1/activity`) | ✗ (403) | ✓ |

A normal inference key works — the widget shows key-level usage and clearly
states that account credits and spend history require a **management key**.
Create one at <https://openrouter.ai/settings/keys> (⚠ a management key can
spend credits and manage your account — treat it as a secret).

## Architecture

```
Sources/
├── OpenRouterWidgetCore/        # all logic + views (library, unit-testable)
│   ├── API/                     # URLSession client, Codable models, typed errors
│   ├── Credentials/             # CredentialStore protocol + Keychain/in-memory impls
│   ├── Models/                  # UsageSnapshot, SpendCalculator (local-tz periods)
│   ├── Services/                # UsageService, RefreshScheduler, SnapshotCache, LaunchAtLogin
│   ├── App/AppState.swift       # @MainActor observable state
│   ├── Views/                   # popover, balance, summary, chart, models, setup, settings
│   └── Utilities/               # currency/date helpers, OSLog, model-name formatting
└── OpenRouterWidget/            # thin executable: @main, MenuBarExtra + Settings scenes
Tests/OpenRouterWidgetTests/      # decoding, API error mapping, spend math, credentials
```

Design decisions (data sources, timezone semantics, permission UX) are recorded
in [`docs/api.md`](docs/api.md) and [`docs/reference-review.md`](docs/reference-review.md).

- **Networking:** `URLSession` + async/await, injectable session/base URL,
  no SwiftUI dependencies in the API layer. Status codes map to typed errors
  (401/403/429/500…), OpenRouter's error message is surfaced in the UI.
- **Refresh:** after launch, after connecting a key, manually (⌘R), and on a
  configurable interval (1/5/15/30/60 min or manual-only). Duplicate
  concurrent refreshes are guarded.
- **Caching:** last successful snapshot is kept in memory and mirrored to a
  small JSON file in Application Support. A failed refresh never evicts good
  data — the footer shows “Updated 4 min ago · Could not refresh”.
- **Logging:** OSLog (`API`/`Refresh`/`Credentials`/`App` categories). Keys and
  response payloads are never logged.

## Testing

```bash
swift test
```

34 tests cover API decoding (fixture JSON modelled on the official OpenAPI
examples), error mapping (401/403/429/500/malformed/offline/timeout), spend
math (today/week/month/30-day windows, timezone boundaries, model grouping),
the credential abstraction (in-memory + real-Keychain round-trip where
available), and the refresh orchestration. No network access or real
OpenRouter account is needed. *(Two Keychain tests auto-skip on hosts where
the test runner cannot access the Keychain.)*

## Security notes

- The API key lives only in the macOS Keychain, accessible after first unlock
  on this device only.
- The key is sent only to `https://openrouter.ai/api/v1` (Bearer auth).
- The key is never printed, logged, or written to disk/Git; the settings UI
  shows only a masked form (`•••••••• 890`).

## Known limitations

- `/api/v1/activity` returns only the **last 30 completed UTC days**, so
  today's spend comes from the key-usage figures (`usage_daily`) instead —
  and it is **per-key**, not account-wide. Week/month figures are computed in
  your local timezone from activity (management key) and lag by up to one day.
- Without a management key, the balance shows the **key's remaining spending
  limit** (not account credits), and week/month figures fall back to the key's
  own UTC-period usage.
- No database, sync, or history beyond what OpenRouter's API provides.
- Launch at Login uses `SMAppService` and requires the packaged `.app`.

## Packaging

`scripts/package-app.sh` builds a release binary, assembles an `.app` bundle
(with `LSUIElement` so it stays menu-bar-only) and ad-hoc codesigns it. For
distribution, re-sign with a Developer ID and notarize; no other dependencies
are involved.
