# OpenRouter API — verified decisions

Source of truth: the official OpenRouter OpenAPI specification
(`https://openrouter.ai/openapi.json`, server `https://openrouter.ai/api/v1`),
retrieved and inspected at implementation time. No undocumented endpoints or
fields are used.

## Endpoints

### `GET /api/v1/key`

- **Auth:** `Authorization: Bearer <key>` — works with *any* valid OpenRouter
  API key (inference keys included).
- **Response:** `{ "data": { ... } }` with fields:
  - `label` (string) — masked key label, e.g. `sk-or-v1-au7...890`
  - `limit`, `limit_remaining`, `limit_reset` — key spending limit in USD
    (nullable; `null` = no limit set)
  - `usage`, `usage_daily`, `usage_weekly`, `usage_monthly` — OpenRouter
    credit usage in USD for the key. Daily = current **UTC** day,
    weekly = current **UTC** week (**Monday–Sunday**), monthly = current
    **UTC** month.
  - `byok_usage`, `byok_usage_daily`, `byok_usage_weekly`, `byok_usage_monthly`
    — external BYOK spend in USD (same UTC period semantics)
  - `is_free_tier`, `is_management_key`, `is_provisioning_key`, `include_byok_in_limit`
  - `expires_at` (nullable ISO-8601 UTC timestamp)
  - `creator_user_id`, `rate_limit` (deprecated by OpenRouter; ignored)
- **Errors:** 400 / 401 / 403 / 404 / 500.

### `GET /api/v1/credits`

- **Auth:** `Authorization: Bearer <key>` — **requires a management key**.
  A normal inference key receives `403 "Only management keys can perform this
  operation"`.
- **Response:** `{ "data": { "total_credits": number, "total_usage": number } }`
  (USD). **Remaining credits = `total_credits − total_usage`.** The widget
  labels this value "Available credits" — it is the account-level remaining
  credit, not total purchased credits.

### `GET /api/v1/activity`

- **Auth:** **requires a management key** (same 403 behaviour as credits).
- **Historical limitation (verified in the official spec):** returns activity
  grouped by endpoint "for the last 30 (completed) UTC days". The current UTC
  day is **not included**. There is no pagination — one response covers the
  whole window. Optional query params (`date`, `api_key_hash`, `user_id`,
  `workspace_id`, `group_by`) are not used by this widget.
- **Response:** `{ "data": [ item ] }`, item fields:
  - `date` — UTC day label, `YYYY-MM-DD`
  - `model` — model slug, e.g. `openai/gpt-4.1`; `model_permaslug`
  - `endpoint_id`, `provider_name`
  - `usage` — cost in USD (OpenRouter credits spent)
  - `byok_usage_inference` — BYOK inference cost in USD
  - `requests`, `prompt_tokens`, `completion_tokens`, `reasoning_tokens`
- Empty response = `{ "data": [] }`.

## Rate limits / errors

OpenRouter returns JSON error bodies of the shape
`{ "error": { "code": number, "message": string } }` for 400/401/403/404/500.
The widget maps status codes to typed errors and surfaces the server message in
the UI. No documented per-endpoint rate limit applies to these management
endpoints; a 429 is handled generically.

## Widget data-source decisions

1. **Balance hero number** — remaining account credits from `/credits`
   (management key). Without a management key the widget shows the key's
   `limit_remaining` clearly labeled "Key limit remaining" and states that
   account credits require a management key.

2. **"Today" spend** — from `/key` `usage_daily + byok_usage_daily`. This is the
   only source that includes the current day (activity covers only *completed*
   UTC days, so an activity-based "today" would read $0.00 all day).
   Caveat: it is the usage of the *configured key* (not account-wide), for the
   current **UTC** day.

3. **"This week" / "This month"** — computed by `SpendCalculator` from activity
   data in the user's **local timezone** (week = **Monday–Sunday** local, same
   weekday convention OpenRouter itself uses; month = calendar month local).
   Caveat: activity excludes today and days older than 30, so these values can
   lag today's spend by one day and exclude spend before the 30-day window.
   If the key has no management permissions (no activity), the widget falls
   back to `/key` `usage_weekly / usage_monthly` and labels the rows
   "key usage · UTC periods" so the two semantics are never mixed silently.

4. **30-day chart / "Top models"** — from activity data (`usage +
   byok_usage_inference`), UTC-day buckets displayed as calendar days, local
   30-day window.

These caveats are surfaced in the UI captions and the README "Known
limitations" section.
