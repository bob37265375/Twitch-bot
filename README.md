# Twitch Bot

This is a **Twitch bot** with:

- OBS integration (alerts, scene switching)
- TikTok → Twitch chat bridge
- SQLite database for user stats
- Timers and auto-moderation

## Getting Started

1. Clone repo:
git clone https://github.com/<YOUR_GITHUB_USERNAME>/twitch-bot.git

markdown
Copy code

2. Install dependencies:
npm install

markdown
Copy code

3. Configure `config.json` with your Twitch and TikTok credentials.

4. Run bot:
node index.js

markdown
Copy code

## Optional

- Run 24/7 using **PM2**
pm2 start index.js --name twitch-bot
pm2 save
pm2 startup
