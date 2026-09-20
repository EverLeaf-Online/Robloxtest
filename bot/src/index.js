import 'dotenv/config';
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import {
  Client,
  EmbedBuilder,
  Events,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder,
} from 'discord.js';

import {
  PayloadTooLargeError,
  boundedText,
  parseAnalyticsAlertMessage,
  parsePort,
  readBody,
  safeSecretEqual,
  stableWebhookNotificationKey,
  validateHttpsUrl,
  verifyRobloxWebhookSignature,
} from './lib.js';

const required = ['DISCORD_TOKEN', 'DISCORD_CLIENT_ID', 'DISCORD_GUILD_ID'];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required environment variable: ${key}`);
}

const guildId = process.env.DISCORD_GUILD_ID;
const gameUrl = validateHttpsUrl(
  process.env.ROBLOX_GAME_URL ?? 'https://www.roblox.com/games/75490500628229',
);
const webhookSecret = process.env.ROBLOX_WEBHOOK_SECRET;
const platformWebhookSecret = process.env.ROBLOX_PLATFORM_WEBHOOK_SECRET;
const webhookPort = parsePort(process.env.WEBHOOK_PORT, 8787);
const webhookHost = process.env.WEBHOOK_HOST ?? '127.0.0.1';
const platformWebhookSpoolDir =
  process.env.ROBLOX_PLATFORM_WEBHOOK_SPOOL_DIR ??
  path.join(process.cwd(), 'data', 'platform-webhooks');
const platformWebhookMaxFiles = 2000;

const channelConfig = Object.freeze({
  announcements: {
    id: process.env.DISCORD_ANNOUNCEMENTS_CHANNEL_ID,
    name: 'announcements',
  },
  bugReports: {
    id: process.env.DISCORD_BUG_REPORTS_CHANNEL_ID,
    name: 'bug-reports',
  },
  feedback: {
    id: process.env.DISCORD_FEEDBACK_CHANNEL_ID,
    name: 'feedback',
  },
  ops: {
    id: process.env.DISCORD_OPS_CHANNEL_ID,
    name: null,
  },
});

const commands = [
  new SlashCommandBuilder().setName('help').setDescription('Show Scrap-to-Bot Factory bot commands.'),
  new SlashCommandBuilder()
    .setName('report')
    .setDescription('Submit a bug report to #bug-reports.')
    .addStringOption((option) =>
      option
        .setName('details')
        .setDescription('What happened?')
        .setRequired(true)
        .setMaxLength(1800),
    ),
  new SlashCommandBuilder()
    .setName('feedback')
    .setDescription('Submit an idea or gameplay feedback.')
    .addStringOption((option) =>
      option
        .setName('details')
        .setDescription('Your feedback')
        .setRequired(true)
        .setMaxLength(1800),
    ),
  new SlashCommandBuilder().setName('status').setDescription('Show the Roblox game link and bot status.'),
  new SlashCommandBuilder().setName('updates').setDescription('Show where game updates are posted.'),
].map((command) => command.toJSON());

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

async function registerCommands() {
  const rest = new REST({ version: '10' }).setToken(process.env.DISCORD_TOKEN);
  await rest.put(Routes.applicationGuildCommands(process.env.DISCORD_CLIENT_ID, guildId), {
    body: commands,
  });
}

async function resolveTextChannel(guild, config) {
  let channel = null;

  if (config.id) {
    channel = await guild.channels.fetch(config.id).catch(() => null);
  }

  if (!channel && config.name) {
    channel = guild.channels.cache.find((candidate) => candidate.name === config.name) ?? null;
  }

  if (!channel && config.name) {
    await guild.channels.fetch().catch(() => null);
    channel = guild.channels.cache.find((candidate) => candidate.name === config.name) ?? null;
  }

  return channel?.isTextBased() ? channel : null;
}

async function replyFailure(interaction, content) {
  if (interaction.replied || interaction.deferred) {
    await interaction.followUp({ content, ephemeral: true }).catch(() => {});
    return;
  }

  await interaction.reply({ content, ephemeral: true }).catch(() => {});
}

async function handleInteraction(interaction) {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'help') {
    await interaction.reply({
      embeds: [
        new EmbedBuilder()
          .setTitle('Scrap-to-Bot Factory')
          .setDescription(
            '`/report` send a bug report\n`/feedback` share an idea\n`/status` show game status\n`/updates` find update announcements',
          ),
      ],
      ephemeral: true,
    });
    return;
  }

  if (interaction.commandName === 'status') {
    await interaction.reply({
      content: `Game: ${gameUrl}\nBot: online`,
      allowedMentions: { parse: [] },
    });
    return;
  }

  if (interaction.commandName === 'updates') {
    await interaction.reply({
      content: 'Game updates and patch notes are posted in #announcements.',
      allowedMentions: { parse: [] },
    });
    return;
  }

  if (interaction.commandName !== 'report' && interaction.commandName !== 'feedback') {
    await replyFailure(interaction, 'Unknown command.');
    return;
  }

  if (!interaction.guild || interaction.guild.id !== guildId) {
    await replyFailure(interaction, 'This command is only available in the Scrap-to-Bot Factory server.');
    return;
  }

  const isReport = interaction.commandName === 'report';
  const config = isReport ? channelConfig.bugReports : channelConfig.feedback;
  const channel = await resolveTextChannel(interaction.guild, config);
  if (!channel) {
    await replyFailure(interaction, `#${config.name} is unavailable right now. Please try again later.`);
    return;
  }

  const details = boundedText(interaction.options.getString('details', true), '(no details)', 1800);
  const label = isReport ? 'Bug report' : 'Feedback';
  const author = boundedText(interaction.user.username, 'unknown-user', 80);
  const message = `**${label}** from ${author} (${interaction.user.id}):\n${details}`;

  await channel.send({
    content: message,
    allowedMentions: { parse: [] },
  });
  await interaction.reply({
    content: `Sent to #${config.name}.`,
    ephemeral: true,
  });
}

client.once(Events.ClientReady, (readyClient) => {
  console.log(`Logged in as ${readyClient.user.tag}`);
});

client.on(Events.InteractionCreate, (interaction) => {
  void handleInteraction(interaction).catch(async (error) => {
    console.error('Discord interaction error:', error);
    if (interaction.isRepliable()) {
      await replyFailure(interaction, 'The bot could not complete that request. Please try again.');
    }
  });
});

function parseJsonObject(rawBody) {
  const payload = JSON.parse(rawBody);
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('Webhook payload must be a JSON object');
  }
  return payload;
}

function validatePlatformWebhookPayload(payload) {
  const notificationId = payload.NotificationId;
  const eventType = payload.EventType;
  const eventTime = payload.EventTime;
  const eventPayload = payload.EventPayload;

  if (
    typeof notificationId !== 'string' ||
    notificationId.length < 1 ||
    notificationId.length > 256
  ) {
    throw new Error('Invalid NotificationId');
  }
  if (typeof eventType !== 'string' || eventType.length < 1 || eventType.length > 128) {
    throw new Error('Invalid EventType');
  }
  if (typeof eventTime !== 'string' || eventTime.length > 128 || Number.isNaN(Date.parse(eventTime))) {
    throw new Error('Invalid EventTime');
  }
  if (eventPayload === null || typeof eventPayload !== 'object' || Array.isArray(eventPayload)) {
    throw new Error('Invalid EventPayload');
  }

  const analyticsAlert =
    eventType === 'AnalyticsAlert' ? parseAnalyticsAlertMessage(eventPayload) : null;

  return { notificationId, eventType, eventTime, analyticsAlert };
}

async function persistPlatformNotification(payload, notificationId) {
  await fs.mkdir(platformWebhookSpoolDir, { recursive: true, mode: 0o700 });

  const key = stableWebhookNotificationKey(notificationId);
  const target = path.join(platformWebhookSpoolDir, `${key}.json`);
  let handle;

  try {
    handle = await fs.open(target, 'wx', 0o600);
    await handle.writeFile(`${JSON.stringify(payload)}\n`, 'utf8');
    return true;
  } catch (error) {
    if (error?.code === 'EEXIST') return false;
    throw error;
  } finally {
    await handle?.close();
  }
}

async function prunePlatformWebhookSpool() {
  let entries;
  try {
    entries = await fs.readdir(platformWebhookSpoolDir, { withFileTypes: true });
  } catch (error) {
    if (error?.code === 'ENOENT') return;
    throw error;
  }

  const files = entries.filter((entry) => entry.isFile() && entry.name.endsWith('.json'));
  if (files.length <= platformWebhookMaxFiles) return;

  const withStats = await Promise.all(
    files.map(async (entry) => {
      const fullPath = path.join(platformWebhookSpoolDir, entry.name);
      const stats = await fs.stat(fullPath);
      return { fullPath, mtimeMs: stats.mtimeMs };
    }),
  );
  withStats.sort((a, b) => a.mtimeMs - b.mtimeMs);

  const removeCount = withStats.length - platformWebhookMaxFiles;
  await Promise.all(withStats.slice(0, removeCount).map(({ fullPath }) => fs.unlink(fullPath)));
}

async function sendPlatformWebhookOpsSummary(summary) {
  if (!channelConfig.ops.id) return;

  const guild = client.guilds.cache.get(guildId) ?? (await client.guilds.fetch(guildId));
  const channel = await resolveTextChannel(guild, channelConfig.ops);
  if (!channel) {
    console.warn('[RobloxPlatformWebhook] DISCORD_OPS_CHANNEL_ID is not accessible.');
    return;
  }

  const embed = new EmbedBuilder();

  if (summary.analyticsAlert) {
    const alert = summary.analyticsAlert;
    embed
      .setTitle(
        alert.status === 'Recovered'
          ? 'Roblox analytics alert recovered'
          : alert.status === 'Fired'
            ? 'Roblox analytics alert fired'
            : 'Roblox analytics alert',
      )
      .setDescription(boundedText(alert.summary, 'Roblox analytics alert', 4000))
      .addFields(
        { name: 'Metric', value: boundedText(alert.metric, 'Unknown', 1024), inline: true },
        { name: 'Status', value: boundedText(alert.status, 'Unknown', 1024), inline: true },
        {
          name: 'Evaluation time',
          value: boundedText(alert.evaluationTimeUtc, 'Unknown', 1024),
          inline: true,
        },
        {
          name: 'Universe',
          value: `\`${boundedText(alert.universeId, 'Unknown', 128)}\``,
          inline: true,
        },
        {
          name: 'Notification',
          value: `\`${boundedText(summary.notificationId, 'Unknown', 128)}\``,
        },
      );

    if (alert.severity) {
      embed.addFields({
        name: 'Severity',
        value: boundedText(alert.severity, 'Unknown', 1024),
        inline: true,
      });
    }

    if (alert.alertHistoryUrl) {
      embed.setURL(alert.alertHistoryUrl);
    }
  } else {
    embed
      .setTitle('Roblox platform webhook')
      .addFields(
        { name: 'Event', value: boundedText(summary.eventType, 'Unknown', 128), inline: true },
        {
          name: 'Notification',
          value: `\`${boundedText(summary.notificationId, 'Unknown', 128)}\``,
        },
        { name: 'Event time', value: boundedText(summary.eventTime, 'Unknown', 128) },
      );
  }

  await channel.send({
    embeds: [embed],
    allowedMentions: { parse: [] },
  });
}

async function handleGameEventWebhook(request, response) {
  if (!webhookSecret) {
    response.writeHead(503);
    response.end('Game event webhook is not configured');
    return;
  }

  const suppliedSecret = request.headers['x-roblox-webhook-secret'];
  if (!safeSecretEqual(suppliedSecret, webhookSecret)) {
    response.writeHead(401);
    response.end('Unauthorized');
    return;
  }

  const rawBody = await readBody(request);
  const payload = parseJsonObject(rawBody);

  const guild = client.guilds.cache.get(guildId) ?? (await client.guilds.fetch(guildId));
  const channel = await resolveTextChannel(guild, channelConfig.announcements);
  if (!channel) {
    response.writeHead(503);
    response.end('Announcements channel unavailable');
    return;
  }

  const title = boundedText(payload.title, 'Roblox game event', 256);
  const description = boundedText(
    payload.description ?? payload.message,
    'A new event was received.',
    4000,
  );

  await channel.send({
    embeds: [new EmbedBuilder().setTitle(title).setDescription(description).setURL(gameUrl)],
    allowedMentions: { parse: [] },
  });

  response.writeHead(204);
  response.end();
}

async function handlePlatformWebhook(request, response) {
  if (!platformWebhookSecret) {
    response.writeHead(503);
    response.end('Roblox platform webhook is not configured');
    return;
  }

  const rawBody = await readBody(request);
  const payload = parseJsonObject(rawBody);
  const summary = validatePlatformWebhookPayload(payload);

  if (
    !verifyRobloxWebhookSignature(
      request.headers['roblox-signature'],
      platformWebhookSecret,
      payload,
    )
  ) {
    response.writeHead(401);
    response.end('Unauthorized');
    return;
  }

  const isNew = await persistPlatformNotification(payload, summary.notificationId);

  response.writeHead(204);
  response.end();

  if (!isNew) {
    console.log(
      `[RobloxPlatformWebhook] duplicate notification ignored: ${summary.notificationId}`,
    );
    return;
  }

  console.log(
    `[RobloxPlatformWebhook] accepted type=${summary.eventType} notification=${summary.notificationId} eventTime=${summary.eventTime}`,
  );

  void sendPlatformWebhookOpsSummary(summary).catch((error) => {
    console.error('[RobloxPlatformWebhook] Discord ops summary failed:', error);
  });
  void prunePlatformWebhookSpool().catch((error) => {
    console.error('[RobloxPlatformWebhook] spool pruning failed:', error);
  });
}

function startWebhookServer() {
  if (!webhookSecret && !platformWebhookSecret) {
    console.warn('No Roblox webhook secrets are configured; webhook receiver is disabled.');
    return null;
  }

  const server = http.createServer(async (request, response) => {
    request.setTimeout(10_000, () => {
      if (!response.headersSent) response.writeHead(408);
      response.end();
      request.destroy();
    });

    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(
        JSON.stringify({
          ok: true,
          gameEvents: Boolean(webhookSecret),
          platformWebhooks: Boolean(platformWebhookSecret),
        }),
      );
      return;
    }

    if (request.method !== 'POST') {
      response.writeHead(404);
      response.end();
      return;
    }

    if (request.url !== '/roblox/events' && request.url !== '/roblox/platform-webhook') {
      response.writeHead(404);
      response.end();
      return;
    }

    const contentType = request.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().startsWith('application/json')) {
      response.writeHead(415);
      response.end('Expected application/json');
      return;
    }

    try {
      if (request.url === '/roblox/events') {
        await handleGameEventWebhook(request, response);
      } else {
        await handlePlatformWebhook(request, response);
      }
    } catch (error) {
      if (response.writableEnded) return;

      if (error instanceof PayloadTooLargeError) {
        request.resume();
        response.writeHead(413);
        response.end('Webhook body too large');
        return;
      }

      console.error('Roblox webhook error:', error);
      response.writeHead(400);
      response.end('Invalid webhook payload');
    }
  });

  server.headersTimeout = 15_000;
  server.requestTimeout = 15_000;
  server.keepAliveTimeout = 5_000;
  server.on('error', (error) => {
    console.error('Webhook server error:', error);
  });

  server.listen(webhookPort, webhookHost, () => {
    console.log(`Roblox webhook receiver listening on ${webhookHost}:${webhookPort}`);
  });

  return server;
}

await registerCommands();
await client.login(process.env.DISCORD_TOKEN);
await prunePlatformWebhookSpool().catch((error) => {
  console.error('[RobloxPlatformWebhook] initial spool pruning failed:', error);
});
const webhookServer = startWebhookServer();

let shuttingDown = false;
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`Received ${signal}; shutting down.`);

  if (webhookServer) {
    await new Promise((resolve) => {
      webhookServer.close(() => resolve());
      setTimeout(resolve, 5_000).unref();
    });
  }

  client.destroy();
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => {
    void shutdown(signal).finally(() => process.exit(0));
  });
}
