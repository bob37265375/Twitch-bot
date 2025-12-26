#!/bin/bash

# --- Variables ---
BOT_DIR="$HOME/twitch-bot"

# --- Create folder ---
mkdir -p "$BOT_DIR"
cd "$BOT_DIR" || exit

# --- Initialize Git ---
git init
git branch -M main

# --- Create package.json ---
cat > package.json <<EOL
{
  "name": "twitch-bot",
  "version": "1.0.0",
  "description": "Linux Twitch bot with OBS and TikTok integration",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "tmi.js": "^1.9.1",
    "obs-websocket-js": "^5.1.0",
    "bad-words": "^3.0.4",
    "better-sqlite3": "^8.0.1",
    "tiktok-live-connector": "^1.5.0"
  }
}
EOL

# --- Create .gitignore ---
cat > .gitignore <<EOL
node_modules/
bot.db
config.json
.env
EOL

# --- Create config.json template ---
cat > config.json <<EOL
{
  "bot": {
    "username": "BOT_USERNAME",
    "oauth": "oauth:YOUR_TWITCH_OAUTH",
    "channel": "YOUR_CHANNEL"
  },
  "tiktok": {
    "username": "TIKTOK_USERNAME"
  },
  "permissions": {
    "mods": ["say", "alert", "scene"],
    "everyone": ["help", "discord", "stats"]
  },
  "timers": [
    { "message": "Follow the stream!", "interval": 600000 },
    { "message": "Join our Discord!", "interval": 900000 }
  ]
}
EOL

# --- Create database.js ---
cat > database.js <<EOL
const Database = require("better-sqlite3");
const db = new Database("bot.db");

db.prepare(\`
CREATE TABLE IF NOT EXISTS users (
  username TEXT PRIMARY KEY,
  messages INTEGER DEFAULT 0
)
\`).run();

function addMessage(username) {
  db.prepare(\`
    INSERT INTO users (username, messages)
    VALUES (?, 1)
    ON CONFLICT(username)
    DO UPDATE SET messages = messages + 1
  \`).run(username);
}

module.exports = { addMessage };
EOL

# --- Create obs.js ---
cat > obs.js <<EOL
const OBSWebSocket = require("obs-websocket-js").default;
const obs = new OBSWebSocket();

(async () => {
  await obs.connect("ws://127.0.0.1:4455", "OBS_PASSWORD");
  console.log("🎥 OBS Connected");
})();

async function triggerAlert() {
  await obs.call("SetInputSettings", {
    inputName: "Alert Sound",
    inputSettings: { restart: true }
  });
}

async function switchScene(scene) {
  await obs.call("SetCurrentProgramScene", { sceneName: scene });
}

module.exports = { triggerAlert, switchScene };
EOL

# --- Create tiktok.js ---
cat > tiktok.js <<EOL
const { WebcastPushConnection } = require("tiktok-live-connector");

function startTikTok(username, twitchClient, channel) {
  const tt = new WebcastPushConnection(username);
  tt.connect();

  tt.on("chat", data => {
    twitchClient.say(channel, \`📱 TikTok | \${data.uniqueId}: \${data.comment}\`);
  });
}

module.exports = { startTikTok };
EOL

# --- Create index.js ---
cat > index.js <<'EOL'
const tmi = require("tmi.js");
const Filter = require("bad-words");
const config = require("./config.json");
const { triggerAlert, switchScene } = require("./obs");
const { startTikTok } = require("./tiktok");
const { addMessage } = require("./database");

const filter = new Filter();
let stats = { messages: 0, users: new Set() };

const client = new tmi.Client({
  identity: { username: config.bot.username, password: config.bot.oauth },
  channels: [config.bot.channel]
});

client.connect();
startTikTok(config.tiktok.username, client, `#${config.bot.channel}`);

// Timers
config.timers.forEach(timer => {
  setInterval(() => client.say(`#${config.bot.channel}`, timer.message), timer.interval);
});

// Chat handling
client.on("message", (channel, tags, message, self) => {
  if (self) return;

  stats.messages++;
  stats.users.add(tags.username);
  addMessage(tags.username);

  if (filter.isProfane(message)) {
    client.say(channel, `/timeout ${tags.username} 10`);
    return;
  }

  if (!message.startsWith("!")) return;
  const args = message.slice(1).split(" ");
  const cmd = args.shift().toLowerCase();
  const isMod = tags.mod || tags.badges?.broadcaster;

  if (cmd === "help") client.say(channel, "Commands: !help !discord !stats");
  if (cmd === "discord") client.say(channel, "Join our Discord: https://discord.gg/yourlink");
  if (cmd === "stats") client.say(channel, `Messages: ${stats.messages} | Users: ${stats.users.size}`);

  if (cmd === "alert" && isMod) triggerAlert();
  if (cmd === "scene" && isMod) switchScene("BRB");
  if (cmd === "say" && isMod) client.say(channel, args.join(" "));
});
EOL

# --- Create README.md ---
cat > README.md <<EOL
# Twitch Bot

Linux Twitch bot with:

- OBS integration (alerts & scene switching)
- TikTok → Twitch bridge
- SQLite database for user stats
- Timers and auto-moderation

## Getting Started

1. Clone repo:
\`\`\`
git clone <YOUR_REPO_URL>
\`\`\`

2. Install dependencies:
\`\`\`
npm install
\`\`\`

3. Configure \`config.json\` with your Twitch/TikTok credentials.

4. Run bot:
\`\`\`
node index.js
\`\`\`

## Optional 24/7 Hosting

- Use PM2:
\`\`\`
sudo npm install -g pm2
pm2 start index.js --name twitch-bot
pm2 save
pm2 startup
\`\`\`
EOL

# --- Install Dependencies ---
npm install

# --- Install PM2 globally ---
sudo npm install -g pm2

echo "✅ Twitch bot setup complete! Edit config.json and run 'node index.js' or use PM2 to run 24/7."

