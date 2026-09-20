# Scrap-to-Bot Factory Discord bot

This is the first safe bot implementation for the Discord server. It uses slash commands and only needs the permissions configured in the Discord Developer Portal.

## Setup

1. Copy `.env.example` to `.env`.
2. Put the bot token in `DISCORD_TOKEN`. Never commit or post this value.
3. Run `npm install` inside this folder.
4. Run `npm start`.

The bot registers guild commands when `DISCORD_GUILD_ID` is set, so changes appear quickly in the Scrap to Bot Factory server.

## Roblox webhook bridge

Set `ROBLOX_WEBHOOK_SECRET` and expose `POST /roblox/events` through a secure HTTPS host. Configure the Roblox webhook to send the same value in the `x-roblox-webhook-secret` header. The receiver posts sanitized event titles/descriptions to `#announcements`; it never accepts or logs a Discord token.
