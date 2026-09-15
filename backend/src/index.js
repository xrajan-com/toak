const http = require('node:http');
const path = require('node:path');
const crypto = require('node:crypto');

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { appReleaseRouter } = require('./routes/app_release');
const { authRouter } = require('./routes/auth');
const { economyRouter } = require('./routes/economy');
const {
  leaderboardRouter,
  _syncLeaderboard,
} = require('./routes/leaderboard');
const {
  ECONOMY_CATALOG_CONTENT_HASH,
  ECONOMY_CATALOG_VERSION,
  SUPPORTED_ECONOMY_CATALOG_VERSIONS,
  campaignEventCount,
} = require('./economy_catalog');

const DEFAULT_PRODUCTION_CORS_ORIGINS = [
  'https://tenofakind.com',
  'https://www.tenofakind.com',
  'https://ten-of-a-kind-poker.web.app',
  'https://ten-of-a-kind-poker.firebaseapp.com',
];

function _requestId(raw) {
  if (
    typeof raw === 'string' &&
    raw.length >= 8 &&
    raw.length <= 80 &&
    /^[A-Za-z0-9._:-]+$/.test(raw)
  ) {
    return raw;
  }
  return crypto.randomUUID();
}

function _corsOptions() {
  const raw = (process.env.CORS_ORIGIN ?? '').trim();
  if (!raw) {
    if (process.env.NODE_ENV === 'production') {
      return { origin: DEFAULT_PRODUCTION_CORS_ORIGINS, credentials: false };
    }
    return { origin: '*', credentials: false };
  }
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
  if (process.env.NODE_ENV === 'production') app.set('trust proxy', 1);
  app.use((req, res, next) => {
    const startedAt = process.hrtime.bigint();
    req.requestId = _requestId(req.get('x-request-id'));
    res.set('x-request-id', req.requestId);
    res.on('finish', () => {
      const durationMs =
        Number(process.hrtime.bigint() - startedAt) / 1000000;
      console.log(JSON.stringify({
        severity: res.statusCode >= 500 ? 'ERROR' : 'INFO',
        event: 'http_request',
        requestId: req.requestId,
        method: req.method,
        path: req.route?.path || req.path,
        status: res.statusCode,
        durationMs: Math.round(durationMs),
      }));
    });
    next();
  });
  app.use(helmet());
  app.use(cors(_corsOptions()));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'tenofakind-backend',
      catalogVersion: ECONOMY_CATALOG_VERSION,
      catalogContentHash: ECONOMY_CATALOG_CONTENT_HASH,
      catalogEventCount: campaignEventCount(),
      supportedCatalogVersions: SUPPORTED_ECONOMY_CATALOG_VERSIONS,
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

  app.use('/v1/app-release', appReleaseRouter());
  app.use('/v1/auth', authRouter());
  app.use('/v1/economy', economyRouter({
    refreshLeaderboard: _syncLeaderboard,
  }));
  app.use('/v1/leaderboard', leaderboardRouter());

  app.use((_req, res) => {
    res.status(404).json({
      code: 'not_found',
      error: 'Not found',
      requestId: res.req.requestId,
    });
  });

  app.use((err, req, res, _next) => {
    console.error(JSON.stringify({
      severity: 'ERROR',
      event: 'unhandled_request_error',
      requestId: req.requestId,
      method: req.method,
      path: req.path,
      errorName: err?.name || 'Error',
      errorCode: err?.code || 'internal',
      ...(process.env.NODE_ENV === 'production'
        ? {}
        : { errorMessage: err?.message || 'Internal server error' }),
    }));
    const safeMessage =
      process.env.NODE_ENV === 'production'
        ? 'Internal server error'
        : (err?.message ?? 'Internal server error');
    res.status(500).json({
      code: 'internal',
      error: safeMessage,
      requestId: req.requestId,
    });
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

module.exports = { createApp, start, _corsOptions, DEFAULT_PRODUCTION_CORS_ORIGINS };

if (require.main === module) {
  start().catch((e) => {
    console.error('Failed to start backend:', e);
    process.exitCode = 1;
  });
}
