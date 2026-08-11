const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  SERVER_PROGRESS_COLLECTION,
  _refreshLeaderboard,
} = require('../src/routes/economy');
const {
  isOpaqueLeaderboardDocumentId,
  leaderboardDocumentId,
} = require('../src/leaderboard_identity');
const {
  LEADERBOARD_COLLECTION,
  USERS_COLLECTION,
  _progressStats,
  _pruneLeaderboard,
  _syncLeaderboard,
} = require('../src/routes/leaderboard');
const { FakeFirestore } = require('./firestore_fake');
const {
  ACCOUNT_DELETIONS_COLLECTION,
} = require('../src/security/firebase_auth');

test('public leaderboard ids are stable and do not expose Firebase uids', () => {
  const uid = 'firebase-user-id-123';
  const publicId = leaderboardDocumentId(uid);

  assert.match(publicId, /^lb1_[A-Za-z0-9_-]{43}$/);
  assert.equal(publicId.includes(uid), false);
  assert.equal(isOpaqueLeaderboardDocumentId(publicId), true);
  assert.equal(isOpaqueLeaderboardDocumentId(uid), false);
  assert.equal(leaderboardDocumentId(uid), publicId);
  assert.notEqual(leaderboardDocumentId(`${uid}-other`), publicId);
});

test('leaderboard pruning keeps only the top 10 Aura balances', async () => {
  const leaderboard = {};
  for (let i = 0; i < 38; i += 1) {
    leaderboard[`player${i}`] = {
      displayName: `Player ${i}`,
      auraMilli: 3800 - i,
      rankScore: 3800 - i,
      ...(i === 0
        ? {
          email: 'must-not-migrate@example.com',
          uid: 'must-not-migrate',
          privateNote: 'must-not-migrate',
        }
        : {}),
    };
  }
  const db = new FakeFirestore({
    [LEADERBOARD_COLLECTION]: leaderboard,
  });

  await _pruneLeaderboard(db);

  const expectedIds = Array.from(
    { length: 10 },
    (_, index) => leaderboardDocumentId(`player${index}`),
  ).sort();
  assert.deepEqual(db.ids(LEADERBOARD_COLLECTION), expectedIds);
  const migratedTop = db.dump(
    LEADERBOARD_COLLECTION,
    leaderboardDocumentId('player0'),
  );
  assert.equal(migratedTop.displayName, 'Player 0');
  assert.equal(migratedTop.auraMilli, 3800);
  assert.equal(migratedTop.rankScore, 3800);
  assert.equal(migratedTop.email, undefined);
  assert.equal(migratedTop.uid, undefined);
  assert.equal(migratedTop.privateNote, undefined);
});

test('leaderboard sync writes a qualifying player entry', async () => {
  const uid = 'player1';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [LEADERBOARD_COLLECTION]: {
      [uid]: {
        displayName: 'Legacy Raja',
        auraMilli: 1,
        rankScore: 1,
      },
    },
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: {
        schemaVersion: 1,
        indiaAup: 5000000,
        matchesPlayed: 4,
        finishPermilleSum: 1000,
        activityScore: 12,
        lastActiveAtMs: 1760000000000,
      },
    },
    [USERS_COLLECTION]: {
      [uid]: {
        displayName: 'Raja One',
      },
    },
  });

  const result = await _syncLeaderboard({
    db,
    uid,
    auth: { uid, email: 'player1@example.com' },
  });
  const saved = db.dump(LEADERBOARD_COLLECTION, publicId);

  assert.equal(result.synced, true);
  assert.equal(result.removed, false);
  assert.equal(result.entry.displayName, 'Raja One');
  assert.equal(saved.displayName, 'Raja One');
  assert.equal(saved.totalAup, 5000000);
  assert.ok(saved.rankScore > 0);
  assert.equal(db.dump(LEADERBOARD_COLLECTION, uid), undefined);
  assert.deepEqual(db.ids(LEADERBOARD_COLLECTION), [publicId]);
});

test('Aura-changing economy traffic refreshes the public projection', async () => {
  const uid = 'active-economy-player';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: {
        schemaVersion: 1,
        indiaAup: 2500000,
        activityScore: 4,
      },
    },
    [USERS_COLLECTION]: {
      [uid]: { displayName: 'Active Player' },
    },
  });

  const result = await _refreshLeaderboard({
    db,
    uid,
    refreshLeaderboard: _syncLeaderboard,
    requestId: 'leaderboard-refresh-test',
  });

  assert.equal(result.synced, true);
  assert.equal(
    db.dump(LEADERBOARD_COLLECTION, publicId).displayName,
    'Active Player',
  );
});

test('a newcomer replaces the lowest Aura entry, but not on a tie', async () => {
  const leaderboard = {};
  for (let aura = 1; aura <= 10; aura += 1) {
    leaderboard[leaderboardDocumentId(`incumbent-${aura}`)] = {
      displayName: `Incumbent ${aura}`,
      auraMilli: aura * 1000,
      rankScore: aura * 1000,
    };
  }
  const db = new FakeFirestore({
    [LEADERBOARD_COLLECTION]: leaderboard,
    [SERVER_PROGRESS_COLLECTION]: {
      tied: { schemaVersion: 1, indiaAup: 10000000 },
      newcomer: { schemaVersion: 1, indiaAup: 15000000 },
    },
    [USERS_COLLECTION]: {
      tied: { displayName: 'Tied Player' },
      newcomer: { displayName: 'New Leader' },
    },
  });

  const tied = await _syncLeaderboard({ db, uid: 'tied' });
  assert.deepEqual(tied, {
    synced: false,
    removed: false,
    reason: 'below_top_10',
  });
  assert.equal(db.ids(LEADERBOARD_COLLECTION).length, 10);

  const promoted = await _syncLeaderboard({ db, uid: 'newcomer' });
  assert.equal(promoted.synced, true);
  assert.equal(db.ids(LEADERBOARD_COLLECTION).length, 10);
  assert.equal(
    db.dump(
      LEADERBOARD_COLLECTION,
      leaderboardDocumentId('incumbent-1'),
    ),
    undefined,
  );
  assert.equal(
    db.dump(
      LEADERBOARD_COLLECTION,
      leaderboardDocumentId('newcomer'),
    ).auraMilli,
    1500,
  );
});

test('an unchanged wallet read does not require a leaderboard refresh', async () => {
  const uid = 'wallet-reader';
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: {
        schemaVersion: 1,
        indiaAup: 5000000,
        registeredStarterGranted: true,
      },
    },
  });

  const { _walletForUser } = require('../src/routes/economy');
  const result = await _walletForUser({ db, uid });

  assert.equal(result.auraChanged, false);
});

test('leaderboard refresh failure never rolls back an economy response', async () => {
  const result = await _refreshLeaderboard({
    db: new FakeFirestore(),
    uid: 'active-economy-player',
    refreshLeaderboard: async () => {
      const error = new Error('temporary projection failure');
      error.code = 'unavailable';
      throw error;
    },
    requestId: 'leaderboard-failure-test',
  });

  assert.equal(result, null);
});

test('leaderboard never derives a public name from Firebase Auth claims', async () => {
  const uid = 'private-claims-player';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 5000000 },
    },
  });

  const result = await _syncLeaderboard({
    db,
    uid,
    auth: {
      uid,
      name: 'Private Token Name',
      email: 'private.email@example.com',
    },
  });
  const saved = db.dump(LEADERBOARD_COLLECTION, publicId);

  assert.equal(result.entry.displayName, 'Player');
  assert.equal(saved.displayName, 'Player');
  assert.equal(JSON.stringify(saved).includes('Private Token Name'), false);
  assert.equal(JSON.stringify(saved).includes('private.email'), false);
});

test('leaderboard converts the full 1B AUP economy to 100 Aura', () => {
  const stats = _progressStats({
    indiaAup: 200000000,
    internationalAup: 200000000,
    euroAup: 200000000,
    oceaniaAup: 200000000,
    northAmericaAup: 200000000,
  });

  assert.equal(stats.totalAup, 1000000000);
  assert.equal(stats.auraMilli, 100000);
});

test('leaderboard sync removes opaque and legacy rows when Aura is zero', async () => {
  const uid = 'zero-aura-player';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [LEADERBOARD_COLLECTION]: {
      [uid]: { displayName: 'Legacy Player', rankScore: 2 },
      [publicId]: { displayName: 'Public Player', rankScore: 1 },
    },
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 0 },
    },
  });

  const result = await _syncLeaderboard({
    db,
    uid,
    auth: { uid, email: 'zero@example.com' },
  });

  assert.deepEqual(result, {
    synced: false,
    removed: true,
    reason: 'no_aura',
  });
  assert.deepEqual(db.ids(LEADERBOARD_COLLECTION), []);
});

test('leaderboard sync cannot recreate an entry after account deletion', async () => {
  const uid = 'deleted-leader';
  const db = new FakeFirestore({
    [ACCOUNT_DELETIONS_COLLECTION]: {
      [uid]: { schemaVersion: 1, state: 'locked' },
    },
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 5000000 },
    },
  });

  await assert.rejects(
    _syncLeaderboard({
      db,
      uid,
      auth: { uid, firebase: { sign_in_provider: 'password' } },
    }),
    { code: 'account_deleted' },
  );
  assert.equal(db.dump(LEADERBOARD_COLLECTION, uid), undefined);
  assert.equal(
    db.dump(LEADERBOARD_COLLECTION, leaderboardDocumentId(uid)),
    undefined,
  );
});
