# Scrap-to-Bot Factory Discord bot

Production Discord companion for Scrap-to-Bot Factory. It registers guild-scoped slash commands, receives authenticated in-game event webhooks, and accepts signed Roblox Creator Hub platform webhooks.

## Commands

- `/help`
- `/report` -> `#bug-reports`
- `/feedback` -> `#feedback`
- `/status`
- `/updates`

Report and feedback posts disable Discord mention parsing, so submitted text cannot ping `@everyone`, roles, or users.

## Configuration

Copy `.env.example` to `.env` and set the real values. Never commit `.env` or webhook/Discord secrets.

`DISCORD_GUILD_ID` is required. Commands are intentionally registered only in the configured Scrap-to-Bot Factory guild; the bot does not fall back to global command registration.

Channel IDs are optional for the public/reporting channels. If an ID is absent, the bot resolves the named channel inside the configured guild only. `DISCORD_OPS_CHANNEL_ID`, when configured, must be the exact ID of a private staff channel and does not use a name fallback.

The Roblox experience link must use the root place ID. The current root place is `75490500628229`.

## Webhook endpoints

The listener should bind to loopback and sit behind an HTTPS reverse proxy.

- `GET /health`
- `POST /roblox/events`
  - Internal game/event bridge.
  - Requires `x-roblox-webhook-secret` matching `ROBLOX_WEBHOOK_SECRET`.
  - Posts a bounded embed to `#announcements`.
- `POST /roblox/platform-webhook`
  - Roblox Creator Hub webhook receiver.
  - Requires `ROBLOX_PLATFORM_WEBHOOK_SECRET`.
  - Verifies the `roblox-signature` HMAC-SHA256 signature and a 5-minute timestamp window.
  - Validates the standard `NotificationId`, `EventType`, `EventTime`, and `EventPayload` envelope.
  - Persists accepted notifications by hashed `NotificationId` using exclusive file creation, making duplicate delivery idempotent across process restarts.
  - Keeps a bounded spool of at most 2,000 notification files.
  - Posts platform event summaries to the private `DISCORD_OPS_CHANNEL_ID` when configured. `AnalyticsAlert` events safely parse Roblox's nested `EventPayload.AlertMessage` JSON and surface the alert summary, metric, fired/recovered status, evaluation time, universe ID, optional severity, and a validated `create.roblox.com` alert-history link.

Both POST endpoints require `Content-Type: application/json` and cap bodies at 64 KiB.

Do not subscribe the Creator Hub webhook to Right-to-Erasure events until the production datastore deletion workflow is wired and validated. Receiving and acknowledging a compliance notification is not itself data deletion.

## Development

```bash
npm ci
npm run check
npm test
npm start
```

Node.js 20 or newer is required.
