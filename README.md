<div align="center">

# ⚡ OpenRouter Widget

**A native macOS menu-bar utility for your OpenRouter credits and spend.**

Balance, today / week / month spend, a 30-day chart, and top models — all one glance away, straight from the menu bar.

![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI%20·%20MenuBarExtra-1D9BF0)
![SwiftPM](https://img.shields.io/badge/package-SwiftPM-F05138?logo=swift&logoColor=white)
![Tests](https://img.shields.io/badge/tests-45%20passing-2EA44F)
![Keychain](https://img.shields.io/badge/secrets-Keychain%20only-8B5CF6)
![License](https://img.shields.io/badge/license-MIT-97CA50)

</div>

---

```text
┌────────────────────────────────────┐
│ $21.09                             │
│ Available credits                  │
│                                    │
│ Today                    $0.00     │
│ This week                $1.25     │
│ This month               $5.53     │
│ ────────────────────────────────── │
│ Spend — Last 30 Days        $5.88  │
│         ▁ ▃▁  ▂█▂▁   ▁ ▁           │
│ Top models                         │
│ Gemini 3.8 Flash          $2.82    │
│ GLM 5.3                   $0.45    │
│ ────────────────────────────────── │
│ Updated just now                 ↻ │
│ Settings                         › │
│ Quit OpenRouter Widget             │
└────────────────────────────────────┘
```

*No Dock icon. No web dashboard. No Electron. Just a quiet menu-bar window that answers "how's my OpenRouter account doing?" in about two seconds.*

## ✨ Features

- **💳 Available credits** — the hero number, optionally mirrored in the menu bar as `OR $42.18`
- **📅 Spend rows** — today / this week / this month, exact account-wide values in your local calendar
- **📈 30-day chart** — native Swift Charts, hover any bar for that day's date and amount
- **🏆 Top models** — spend by model over the last 30 days, with long names truncated gracefully
- **🔄 Smart refresh** — manual (⌘R) or automatic (1 min – 1 hour, default 5), with duplicate-refresh protection
- **💾 Resilient cache** — failed refreshes never wipe good data; you keep seeing the last successful numbers with `Updated 4 min ago · Unable to refresh`
- **🔐 Keychain-only credentials** — your API key never touches UserDefaults, files, or Git
- **🚀 Launch at Login** — via the modern `SMAppService` API

## 📦 Install

**Requirements:** macOS 14 Sonoma or newer · Xcode Command Line Tools

```bash
git clone https://github.com/gauravssingh/openrouter-widget.git
cd openrouter-widget

swift build          # build
swift test           # run the 45-test suite (no network or account needed)

scripts/package-app.sh                          # assemble the .app bundle
cp -R .build/OpenRouterWidget.app /Applications/ # install
open /Applications/OpenRouterWidget.app          # launch
```

First launch: click the menu-bar item, paste an OpenRouter API key, done.

> Launch the app via Finder/Spotlight/`open` — never from an SSH session, which macOS bars from Keychain access.

## 🔑 API key & permissions

Create a key at <https://openrouter.ai/settings/keys>. A **management key** unlocks everything:

| Data | Source | Inference key | Management key |
| :--- | :--- | :---: | :---: |
| Key usage & limits | `GET /api/v1/key` | ✓ | ✓ |
| Account credits | `GET /api/v1/credits` | ✗ 403 | ✓ |
| Today / week / month spend | `POST /api/v1/analytics/query` | ✗ 403 | ✓ |
| 30-day chart & top models | `GET /api/v1/activity` | ✗ 403 | ✓ |

With a plain inference key the widget still works — it shows key-level usage and clearly labels what needs a management key. ⚠️ Management keys can spend credits and manage your account: create a dedicated one for the widget and treat it as a secret.

## 🏗️ Architecture

```text
Sources/
├── OpenRouterWidgetCore/            # all logic + views (library, fully unit-testable)
│   ├── API/                         #   URLSession client · Codable models · typed errors
│   ├── Credentials/                 #   CredentialStore protocol → Keychain / in-memory
│   ├── Models/                      #   UsageSnapshot · SpendCalculator · SpendPeriods
│   ├── Services/                    #   UsageService · RefreshScheduler · SnapshotCache
│   ├── App/AppState.swift           #   @MainActor observable state, singleton boot
│   ├── Views/                       #   popover · balance · chart · models · settings · setup
│   └── Utilities/                   #   currency/date helpers · OSLog · model-name formatting
└── OpenRouterWidget/                # thin executable: @main · MenuBarExtra · Settings scene
Tests/OpenRouterWidgetTests/         # 45 tests · fixtures modelled on the official OpenAPI spec
```

Design decisions — data sources, timezone semantics, permission UX — are recorded in [`docs/api.md`](docs/api.md); the review of prior art that shaped this architecture is in [`docs/reference-review.md`](docs/reference-review.md).

Highlights:

- **Zero dependencies** — Swift, SwiftUI, Swift Charts, Security.framework, ServiceManagement. Nothing else.
- **Testable by construction** — protocol-injected networking (`OpenRouterAPI`), credential store, and services; the test suite runs fully offline.
- **Honest numbers** — spend rows come from the analytics API with exact local-period time ranges; every fallback (per-key usage, UTC periods) is labeled in the UI rather than silently mixed.
- **OSLog only** — useful logs, never the key.

## 🔒 Security

- The API key lives **only** in the macOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
- It is sent **only** to `https://openrouter.ai/api/v1` as a Bearer token
- Never printed, logged, cached to disk, or committed; Settings shows only a masked form
- Snapshot cache contains no credentials

## ⚠️ Known limitations

- The 30-day chart comes from `/api/v1/activity`, which OpenRouter limits to the last **30 completed UTC days** — today's bar is absent by design
- Without a management key: balance shows the key's remaining limit, spend rows fall back to per-key UTC figures, no chart
- Launch at Login requires the packaged `.app` (e.g. in `/Applications`)
- For distribution beyond your own Mac, re-sign with a Developer ID and notarize

## 🙏 References

Architecture informed by [godsall-dev/openrouter-usage-menu-macos](https://github.com/godsall-dev/openrouter-usage-menu-macos) and [kittizz/OpenRouterCreditMenuBar](https://github.com/kittizz/OpenRouterCreditMenuBar) — analysis in [`docs/reference-review.md`](docs/reference-review.md). All API usage verified against the [official OpenRouter OpenAPI specification](https://openrouter.ai/openapi.json).

## 📄 License

[MIT](LICENSE) © Gaurav Singh
