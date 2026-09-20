# Scrap-to-Bot Factory Discord bot

Production Discord companion for Scrap-to-Bot Factory. It registers guild-scoped slash commands and can receive authenticated Roblox event webhooks.

## Commands

- `/help`
- `/report` -> `#bug-reports`
- `/feedback` -> `#feedback`
- `/status`
- `/updates`

Report and feedback posts disable Discord mention parsing, so submitted text cannot ping `@everyone`, roles, or users.

## Configuration

Copy `.env.example` to `.env` and set the real values. Never commit `.env` or the Discord/webhook secrets.

`DISCORD_GUILD_ID` is required. Commands are intentionally registered only in the configured Scrap-to-Bot Factory guild; the bot does not fall back to global command registration.

Channel IDs are optional for compatibility with the existing deployment. If an ID is absent, the bot resolves the named channel inside the configured guild only. Channel IDs are preferred for production because they are stable across channel renames.

The Roblox experience link must use the root place ID. The current root place is `75490500628229`.

## Roblox webhook bridge

When `ROBLOX_WEBHOOK_SECRET` is set, the bot exposes:

- `GET /health`
- `POST /roblox/events`

The POST endpoint requires the exact secret in the `x-roblox-webhook-secret` header and `Content-Type: application/json`. Request bodies are capped at 64 KiB, embed fields are bounded to Discord limits, and mention parsing is disabled.

The existing VM deployment listens directly on `WEBHOOK_HOST` / `WEBHOOK_PORT`. For Internet-facing production traffic, terminate HTTPS in front of this listener or otherwise expose it only through a secured transport.

## Development

```bash
npm ci
npm run check
npm test
npm start
```

Node.js 20 or newer is required.
