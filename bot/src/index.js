import 'dotenv/config';
import http from 'node:http';
import {
  Client,
  Collection,
  EmbedBuilder,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder,
} from 'discord.js';

const required = ['DISCORD_TOKEN', 'DISCORD_CLIENT_ID'];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required environment variable: ${key}`);
}

const gameUrl = process.env.ROBLOX_GAME_URL ?? 'https://www.roblox.com/games/10766713640';
const webhookSecret = process.env.ROBLOX_WEBHOOK_SECRET;
const commands = [
  new SlashCommandBuilder().setName('help').setDescription('Show Scrap-to-Bot Factory bot commands.'),
  new SlashCommandBuilder()
    .setName('report')
    .setDescription('Submit a bug report to #bug-reports.')
    .addStringOption((o) => o.setName('details').setDescription('What happened?').setRequired(true)),
  new SlashCommandBuilder()
    .setName('feedback')
    .setDescription('Submit an idea or gameplay feedback.')
    .addStringOption((o) => o.setName('details').setDescription('Your feedback').setRequired(true)),
  new SlashCommandBuilder().setName('status').setDescription('Show the Roblox game link and bot status.'),
  new SlashCommandBuilder().setName('updates').setDescription('Show where game updates are posted.'),
].map((command) => command.toJSON());

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

async function registerCommands() {
  const rest = new REST({ version: '10' }).setToken(process.env.DISCORD_TOKEN);
  const route = process.env.DISCORD_GUILD_ID
    ? Routes.applicationGuildCommands(process.env.DISCORD_CLIENT_ID, process.env.DISCORD_GUILD_ID)
    : Routes.applicationCommands(process.env.DISCORD_CLIENT_ID);
  await rest.put(route, { body: commands });
}

client.once('ready', () => {
  console.log(`Logged in as ${client.user.tag}`);
});

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'help') {
    await interaction.reply({
      embeds: [new EmbedBuilder().setTitle('Scrap-to-Bot Factory').setDescription(
        '`/report` send a bug report\n`/feedback` share an idea\n`/status` show game status\n`/updates` find update announcements',
      )],
      ephemeral: true,
    });
    return;
  }

  if (interaction.commandName === 'status') {
    await interaction.reply(`Game: ${gameUrl}\nBot: online`);
    return;
  }

  if (interaction.commandName === 'updates') {
    await interaction.reply('Game updates and patch notes are posted in #announcements.');
    return;
  }

  const target = interaction.commandName === 'report' ? 'bug-reports' : 'feedback';
  const details = interaction.options.getString('details', true);
  const channel = interaction.guild?.channels.cache.find((candidate) => candidate.name === target);
  const message = `**${interaction.commandName === 'report' ? 'Bug report' : 'Feedback'}** from ${interaction.user}:\n${details}`;
  if (channel?.isTextBased()) await channel.send(message);
  await interaction.reply({ content: `Sent to #${target}.`, ephemeral: true });
});

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', (chunk) => {
      body += chunk;
      if (body.length > 64 * 1024) reject(new Error('Webhook body too large'));
    });
    request.on('end', () => resolve(body));
    request.on('error', reject);
  });
}

function startWebhookServer() {
  if (!webhookSecret) {
    console.warn('ROBLOX_WEBHOOK_SECRET is not set; Roblox webhook receiver is disabled.');
    return;
  }

  const server = http.createServer(async (request, response) => {
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
    if (request.headers['x-roblox-webhook-secret'] !== webhookSecret) {
      response.writeHead(401);
      response.end('Unauthorized');
      return;
    }

    try {
      const payload = JSON.parse(await readBody(request));
      const channel = client.channels.cache.find((candidate) => candidate.name === 'announcements');
      if (channel?.isTextBased()) {
        const title = String(payload.title ?? 'Roblox game event');
        const description = String(payload.description ?? payload.message ?? 'A new event was received.').slice(0, 4000);
        await channel.send({ embeds: [new EmbedBuilder().setTitle(title).setDescription(description).setURL(gameUrl)] });
      }
      response.writeHead(204);
      response.end();
    } catch (error) {
      console.error('Roblox webhook error:', error);
      response.writeHead(400);
      response.end('Invalid webhook payload');
    }
  });

  server.listen(Number(process.env.WEBHOOK_PORT ?? 8787), () => {
    console.log(`Roblox webhook receiver listening on port ${process.env.WEBHOOK_PORT ?? 8787}`);
  });
}

await registerCommands();
await client.login(process.env.DISCORD_TOKEN);
startWebhookServer();
