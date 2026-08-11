const assert = require('node:assert/strict');
const http = require('node:http');
const { afterEach, test } = require('node:test');

const {
  DEFAULT_PRODUCTION_CORS_ORIGINS,
  _corsOptions,
  createApp,
} = require('../src/index');
const {
  ACCOUNT_DELETIONS_COLLECTION,
  ACCOUNT_DOCUMENT_COLLECTIONS,
  RECENT_AUTH_MAX_AGE_SECONDS,
  _deleteAccount,
  _deleteFirebaseUser,
  _isRecentAuth,
  authRouter,
} = require('../src/routes/auth');
const {
  _isRegisteredFirebaseAuth,
  _requireRegisteredUser,
  _verifyFirebaseIdToken,
} = require('../src/security/firebase_auth');
const {
  ECONOMY_CATALOG_CONTENT_HASH,
  ECONOMY_CATALOG_VERSION,
  SUPPORTED_ECONOMY_CATALOG_VERSIONS,
  campaignEventCount,
} = require('../src/economy_catalog');
const { leaderboardDocumentId } = require('../src/leaderboard_identity');
const { FakeFirestore } = require('./firestore_fake');
const { economyRouter } = require('../src/routes/economy');
const { leaderboardRouter } = require('../src/routes/leaderboard');

const originalEnv = { ...process.env };

afterEach(() => {
  process.env = { ...originalEnv };
});

async function withServer(fn) {
  const server = http.createServer(createApp());
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const { port } = server.address();
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  }
}

test('auth-protected API routes reject missing Firebase tokens', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/economy/wallet`);
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {
      error: 'Missing Firebase ID token',
    });
  });
});

test('health reports the exact content-bound economy catalog version', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`);
    const health = await response.json();

    assert.equal(response.status, 200);
    assert.equal(health.ok, true);
    assert.equal(health.catalogVersion, ECONOMY_CATALOG_VERSION);
    assert.equal(health.catalogContentHash, ECONOMY_CATALOG_CONTENT_HASH);
    assert.equal(health.catalogEventCount, campaignEventCount());
    assert.deepEqual(
      health.supportedCatalogVersions,
      SUPPORTED_ECONOMY_CATALOG_VERSIONS,
    );
  });
});

test('legacy register and login endpoints are explicitly retired', async () => {
  await withServer(async (baseUrl) => {
    const register = await fetch(`${baseUrl}/v1/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    });
    const login = await fetch(`${baseUrl}/v1/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    });

    assert.equal(register.status, 410);
    assert.equal(login.status, 410);
  });
});

test('production CORS does not fall back to wildcard origins', () => {
  process.env.NODE_ENV = 'production';
  delete process.env.CORS_ORIGIN;

  assert.deepEqual(_corsOptions(), {
    origin: DEFAULT_PRODUCTION_CORS_ORIGINS,
    credentials: false,
  });
});

test('account deletion requires a fresh Firebase authentication time', () => {
  const nowMs = 1_800_000_000_000;
  const nowSeconds = Math.floor(nowMs / 1000);

  assert.equal(_isRecentAuth(null, nowMs), false);
  assert.equal(_isRecentAuth({}, nowMs), false);
  assert.equal(
    _isRecentAuth(
      { auth_time: nowSeconds - RECENT_AUTH_MAX_AGE_SECONDS },
      nowMs,
    ),
    true,
  );
  assert.equal(
    _isRecentAuth(
      { auth_time: nowSeconds - RECENT_AUTH_MAX_AGE_SECONDS - 1 },
      nowMs,
    ),
    false,
  );
  assert.equal(_isRecentAuth({ auth_time: nowSeconds + 1 }, nowMs), false);
});

test('Firebase token verification checks server-side revocation state', async () => {
  const calls = [];
  const decoded = await _verifyFirebaseIdToken(
    {
      verifyIdToken: async (...args) => {
        calls.push(args);
        return { uid: 'registered-user' };
      },
    },
    'signed-token',
  );

  assert.deepEqual(decoded, { uid: 'registered-user' });
  assert.deepEqual(calls, [['signed-token', true]]);
});

test('shared economy guard rejects anonymous Firebase users only', () => {
  assert.equal(
    _isRegisteredFirebaseAuth({
      firebase: { sign_in_provider: 'anonymous' },
    }),
    false,
  );
  assert.equal(
    _isRegisteredFirebaseAuth({
      firebase: { sign_in_provider: 'password' },
    }),
    true,
  );
  assert.equal(
    _isRegisteredFirebaseAuth({
      firebase: { sign_in_provider: 'google.com' },
    }),
    true,
  );

  let nextCalled = false;
  let statusCode;
  let responseBody;
  const response = {
    status(code) {
      statusCode = code;
      return this;
    },
    json(body) {
      responseBody = body;
      return this;
    },
  };
  _requireRegisteredUser(
    {
      auth: { firebase: { sign_in_provider: 'anonymous' } },
      requestId: 'anonymous-request',
    },
    response,
    () => {
      nextCalled = true;
    },
  );

  assert.equal(nextCalled, false);
  assert.equal(statusCode, 403);
  assert.equal(responseBody.code, 'registered_account_required');
});

test('every shared economy route requires registration while guest deletion remains available', () => {
  const sharedRouters = [economyRouter(), leaderboardRouter()];
  for (const router of sharedRouters) {
    for (const layer of router.stack.filter((candidate) => candidate.route)) {
      const middlewareNames = layer.route.stack.map((entry) => entry.name);
      assert.ok(
        middlewareNames.includes('requireRegisteredFirebaseAuth'),
        `${layer.route.path} must reject anonymous users`,
      );
    }
  }

  const deleteRoute = authRouter().stack.find(
    (layer) => layer.route?.path === '/account',
  );
  const middlewareNames = deleteRoute.route.stack.map((entry) => entry.name);
  assert.ok(middlewareNames.includes('requireFirebaseAuth'));
  assert.equal(middlewareNames.includes('requireRegisteredFirebaseAuth'), false);
});

test('account deletion creates a durable lock before removing user data', async () => {
  const uid = 'delete-me';
  const publicLeaderboardId = leaderboardDocumentId(uid);
  const seed = {
    economy_receipts: {
      ownReceipt: { uid, eventId: 'own-event' },
      otherReceipt: { uid: 'other-user', eventId: 'other-event' },
    },
  };
  for (const collection of ACCOUNT_DOCUMENT_COLLECTIONS) {
    seed[collection] = { [uid]: { marker: collection } };
  }
  seed.leaderboard[publicLeaderboardId] = {
    marker: 'opaque-leaderboard',
  };
  const db = new FakeFirestore(seed);
  let authDeletionObservedLockedData = false;

  await _deleteAccount({
    db,
    uid,
    auth: {
      deleteUser: async (deletedUid) => {
        authDeletionObservedLockedData =
          deletedUid === uid &&
          db.dump(ACCOUNT_DELETIONS_COLLECTION, uid)?.state === 'locked' &&
          ACCOUNT_DOCUMENT_COLLECTIONS.every(
            (collection) => db.dump(collection, uid) === undefined,
          ) &&
          db.dump('leaderboard', publicLeaderboardId) === undefined &&
          db.dump('economy_receipts', 'ownReceipt') === undefined;
      },
    },
  });

  const tombstone = db.dump(ACCOUNT_DELETIONS_COLLECTION, uid);
  assert.equal(authDeletionObservedLockedData, true);
  assert.equal(tombstone.schemaVersion, 1);
  assert.equal(tombstone.state, 'locked');
  for (const collection of ACCOUNT_DOCUMENT_COLLECTIONS) {
    assert.equal(db.dump(collection, uid), undefined);
  }
  assert.equal(db.dump('leaderboard', publicLeaderboardId), undefined);
  assert.equal(db.dump('economy_receipts', 'ownReceipt'), undefined);
  assert.equal(db.dump('economy_receipts', 'otherReceipt').uid, 'other-user');
});

test('Auth deletion is idempotent only for an already-missing user', async () => {
  await _deleteFirebaseUser(
    {
      deleteUser: async () => {
        const error = new Error('missing');
        error.code = 'auth/user-not-found';
        throw error;
      },
    },
    'already-deleted',
  );

  await assert.rejects(
    _deleteFirebaseUser(
      {
        deleteUser: async () => {
          const error = new Error('transient outage');
          error.code = 'auth/internal-error';
          throw error;
        },
      },
      'retry-me',
    ),
    /transient outage/,
  );
});
