import 'dotenv/config';
import http from 'node:http';
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
  parsePort,
  readBody,
  safeSecretEqual,
  validateHttpsUrl,
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
const webhookPort = parsePort(process.env.WEBHOOK_PORT, 8787);
const webhookHost = process.env.WEBHOOK_HOST ?? '0.0.0.0';

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

  if (!channel) {
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

function startWebhookServer() {
  if (!webhookSecret) {
    console.warn('ROBLOX_WEBHOOK_SECRET is not set; Roblox webhook receiver is disabled.');
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
      response.end(JSON.stringify({ ok: true }));
      return;
    }

    if (request.method !== 'POST' || request.url !== '/roblox/events') {
      response.writeHead(404);
      response.end();
      return;
    }

    const suppliedSecret = request.headers['x-roblox-webhook-secret'];
    if (!safeSecretEqual(suppliedSecret, webhookSecret)) {
      response.writeHead(401);
      response.end('Unauthorized');
      return;
    }

    const contentType = request.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().startsWith('application/json')) {
      response.writeHead(415);
      response.end('Expected application/json');
      return;
    }

    try {
      const rawBody = await readBody(request);
      const payload = JSON.parse(rawBody);
      if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
        throw new Error('Webhook payload must be a JSON object');
      }

      const guild = await client.guilds.fetch(guildId);
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
    } catch (error) {
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
