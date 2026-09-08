# Reference review — engineering decision record

Two existing OpenRouter menu-bar projects were reviewed before implementation.

## Project 1: `godsall-dev/openrouter-usage-menu-macos`

SwiftPM project. Split into `OpenRouterMonitorCore` (library: API models,
client, refresh service) and `OpenRouterMonitor` (executable: SwiftUI app).

**Useful patterns (adopted):**
- Library/executable target split — necessary for SwiftPM test targets, which
  cannot link executables. We use the same shape (`OpenRouterWidgetCore` +
  `OpenRouterWidget`).
- `MenuBarExtra` with `.menuBarExtraStyle(.window)` plus a `Settings` scene;
  `NSApplication.setActivationPolicy(.accessory)` in an app delegate.
- Protocol-based fetcher (`OpenRouterFetching`) injected into the service —
  testable without network. Typed client error enum with `LocalizedError`
  descriptions; central request builder attaching the bearer token.
- Optional-endpoint resilience: `/key` is fetched first; credits/activity are
  attempted afterwards and per-endpoint failures degrade into *warnings*
  rather than failing the refresh.
- Correct credits semantics: remaining = `total_credits − total_usage`.
- UTC parsing of activity `YYYY-MM-DD` with a POSIX/UTC formatter.
- `SMAppService.mainApp` for launch-at-login.

**Unnecessary complexity (not adopted):**
- A large dashboard UI (pricing view, "intelligence" cards, budget alerts,
  notifications, multi-key management, currency conversion). Out of MVP scope.
- Big hand-rolled aggregation types (last-7/last-30 windowed summaries with
  "window days" bookkeeping). We keep one small `SpendCalculator`.

**Bugs / limitations noted:** none critical; activity aggregation is done in
UTC only, and "latest day" spend silently lags by a day (the endpoint only
returns completed days) — we address that explicitly via `/key` `usage_daily`
for the "Today" row.

## Project 2: `kittizz/OpenRouterCreditMenuBar`

Xcode project (`.xcodeproj`), manual `NSStatusItem` + `NSPopover` +
`NSHostingController`.

**Useful ideas:** extremely small scope (one endpoint, one number); menu-bar
title shows the balance; default 5-minute refresh interval.

**Problems (not adopted):**
- **Stores the API key in `UserDefaults`** — plaintext in the user's library;
  unacceptable. We use the macOS Keychain exclusively.
- Manual `NSStatusItem`/`NSPopover` plumbing instead of `MenuBarExtra`.
- Refresh `Timer` duplicated in two places (manager + app delegate).
- No typed errors (`URLError(.badServerResponse)` for every failure),
  no caching, no permission handling (`/credits` requires a management key;
  the app shows a generic error), no tests of the API layer.

## Chosen architecture

- **Targets:** `OpenRouterWidgetCore` (all logic + SwiftUI views, testable) and
  a thin `OpenRouterWidget` executable containing only the `@main` app scene.
- **UI:** native `MenuBarExtra` (`.window` style) as the primary UI; `Settings`
  scene for configuration; accessory activation policy (no Dock icon).
- **Credentials:** `CredentialStore` protocol + `KeychainCredentialStore`
  (Security.framework, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`);
  an in-memory implementation is used by tests and SwiftUI previews.
- **API:** `OpenRouterAPI` protocol + `URLSession`-backed client, async/await,
  Codable models generated strictly from the official OpenAPI spec, typed
  errors mapped from status codes, injectable session/base URL for tests.
- **Domain:** `UsageService` fetches `/key` first, then credits/activity for
  management keys (per-endpoint failures become warnings). `SpendCalculator`
  computes local-timezone periods and model totals from activity. See
  `docs/api.md` for the data-source decisions.
- **Refresh:** `AppState` (`@MainActor`) + timer-based `RefreshScheduler`
  (default 5 min, configurable), duplicate-refresh guard, manual refresh.
- **Caching:** in-memory snapshot + small Codable JSON file in Application
  Support so the popover renders instantly on relaunch; failures never evict
  good data ("Updated 4 min ago · Could not refresh").
- **Launch at login:** `SMAppService.mainApp` (macOS 13+ modern API) —
  functional once the app is packaged as `.app` (script provided).
