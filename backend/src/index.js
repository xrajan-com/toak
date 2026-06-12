const http = require('node:http');
const path = require('node:path');

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { authRouter } = require('./routes/auth');
const { economyRouter } = require('./routes/economy');
const { leaderboardRouter } = require('./routes/leaderboard');

function _corsOptions() {
  const raw = (process.env.CORS_ORIGIN ?? '').trim();
  if (!raw) return { origin: '*', credentials: false };
  if (raw === '*') return { origin: '*', credentials: false };

  const allow = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return { origin: allow, credentials: false };
}

function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors(_corsOptions()));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'tenofakind-backend',
      time: new Date().toISOString(),
    });
  });

  const limiter = rateLimit({
    windowMs: 60 * 1000,
    max: 240,
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(limiter);

  app.use('/v1/auth', authRouter());
  app.use('/v1/economy', economyRouter());
  app.use('/v1/leaderboard', leaderboardRouter());

  app.use((_req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  app.use((err, _req, res, _next) => {
    const safeMessage =
      process.env.NODE_ENV === 'production'
        ? 'Internal server error'
        : (err?.message ?? 'Internal server error');
    res.status(500).json({ error: safeMessage });
  });

  return app;
}

async function start() {
  const port = Number.parseInt(process.env.PORT ?? '8080', 10);
  const host = (process.env.HOST ?? '0.0.0.0').toString();

  const app = createApp();
  const server = http.createServer(app);

  await new Promise((resolve) => server.listen(port, host, resolve));
  console.log(`Backend listening on http://${host}:${port}`);

  return server;
}

module.exports = { createApp, start };

if (require.main === module) {
  start().catch((e) => {
    console.error('Failed to start backend:', e);
    process.exitCode = 1;
  });
}
