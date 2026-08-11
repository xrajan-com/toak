const assert = require('node:assert/strict');
const { before, beforeEach, test } = require('node:test');

const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

process.env.FIREBASE_PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'ten-of-a-kind-poker';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID;

const {
  LEGACY_PROGRESS_COLLECTION,
  CLIENT_WALLET_COLLECTION,
  ECONOMY_RECEIPTS_COLLECTION,
  SERVER_PROGRESS_COLLECTION,
  _applyEconomyEvent,
  _walletForUser,
} = require('../src/routes/economy');
const {
  ACCOUNT_DOCUMENT_COLLECTIONS,
  _deleteAccountData,
} = require('../src/routes/auth');
const {
  ACCOUNT_DELETIONS_COLLECTION,
} = require('../src/security/firebase_auth');
const { leaderboardDocumentId } = require('../src/leaderboard_identity');
const {
  LEADERBOARD_COLLECTION,
  USERS_COLLECTION,
  _syncLeaderboard,
} = require('../src/routes/leaderboard');

function requireFirestoreEmulator() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run with: ' +
        'firebase emulators:exec --project ten-of-a-kind-poker ' +
        '--only firestore "npm --prefix backend run test:emulator"',
    );
  }
}

function db() {
  if (admin.getApps().length === 0) {
    admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
  }
  return getFirestore();
}

async function clearCollection(database, name) {
  const docs = await database.collection(name).listDocuments();
  await Promise.all(docs.map((doc) => doc.delete()));
}

async function read(database, collection, id) {
  const snap = await database.collection(collection).doc(id).get();
  return snap.exists ? snap.data() : undefined;
}

before(() => {
  requireFirestoreEmulator();
});

beforeEach(async () => {
  const database = db();
  await Promise.all([
    clearCollection(database, SERVER_PROGRESS_COLLECTION),
    clearCollection(database, LEGACY_PROGRESS_COLLECTION),
    clearCollection(database, CLIENT_WALLET_COLLECTION),
    clearCollection(database, ECONOMY_RECEIPTS_COLLECTION),
    clearCollection(database, LEADERBOARD_COLLECTION),
    clearCollection(database, USERS_COLLECTION),
    clearCollection(database, ACCOUNT_DELETIONS_COLLECTION),
  ]);
});

test('wallet migration writes legacy campaign progress into server progress', async () => {
  const database = db();
  await database.collection(LEGACY_PROGRESS_COLLECTION).doc('emu-wallet').set({
    schemaVersion: 1,
    indiaAup: 7000,
    awardedEventIds: ['legacy:win'],
  });

  const result = await _walletForUser({
    db: database,
    uid: 'emu-wallet',
    allowLegacyMigration: true,
  });
  const server = await read(database, SERVER_PROGRESS_COLLECTION, 'emu-wallet');

  assert.equal(result.exists, true);
  assert.equal(result.migrated, true);
  assert.equal(server.migratedFrom, LEGACY_PROGRESS_COLLECTION);
  assert.equal(server.indiaAup, 7000);
  assert.deepEqual(server.awardedEventIds, ['legacy:win']);
  assert.equal(server.registeredStarterGranted, true);
});

test('economy transaction is idempotent for duplicate event ids', async () => {
  const database = db();
  const body = {
    action: 'campaign_win',
    group: 'india',
    amount: 2500,
    eventId: 'emu:campaign:win:1',
  };

  const first = await _applyEconomyEvent({
    db: database,
    uid: 'emu-economy',
    body,
    allowLegacyUnsafeEvents: true,
  });
  const second = await _applyEconomyEvent({
    db: database,
    uid: 'emu-economy',
    body,
    allowLegacyUnsafeEvents: true,
  });
  const server = await read(database, SERVER_PROGRESS_COLLECTION, 'emu-economy');

  assert.equal(first.accepted, true);
  assert.equal(first.duplicate, false);
  assert.equal(first.delta, 2500);
  assert.equal(second.accepted, true);
  assert.equal(second.duplicate, true);
  assert.equal(second.delta, 0);
  assert.equal(server.indiaAup, 4500);
  assert.deepEqual(server.awardedEventIds, ['emu:campaign:win:1']);
  assert.deepEqual(server.appliedEventIds, ['emu:campaign:win:1']);
});

test('leaderboard sync writes an opaque row and excludes legacy rows', async () => {
  const database = db();
  const uid = 'emu-leader';
  const publicId = leaderboardDocumentId(uid);

  const batch = database.batch();
  for (let i = 0; i < 12; i += 1) {
    batch.set(database.collection(LEADERBOARD_COLLECTION).doc(`old-${i}`), {
      displayName: `Old ${i}`,
      rankScore: i + 1,
    });
  }
  batch.set(database.collection(LEADERBOARD_COLLECTION).doc(uid), {
    displayName: 'Legacy Emu Leader',
    rankScore: 9999,
  });
  batch.set(database.collection(SERVER_PROGRESS_COLLECTION).doc(uid), {
    schemaVersion: 1,
    indiaAup: 6000000,
    matchesPlayed: 3,
    finishPermilleSum: 900,
    activityScore: 20,
    lastActiveAtMs: 1760000000000,
  });
  batch.set(database.collection(USERS_COLLECTION).doc(uid), {
    displayName: 'Emu Leader',
  });
  await batch.commit();

  const result = await _syncLeaderboard({
    db: database,
    uid,
    auth: { uid, email: 'emu-leader@example.com' },
  });

  const entry = await read(database, LEADERBOARD_COLLECTION, publicId);
  const leaderboardDocs = await database
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('auraMilli', 'desc')
    .get();

  assert.equal(result.synced, true);
  assert.equal(entry.displayName, 'Emu Leader');
  assert.equal(entry.totalAup, 6000000);
  assert.equal(await read(database, LEADERBOARD_COLLECTION, uid), undefined);
  assert.equal(leaderboardDocs.docs.length, 1);
  assert.equal(leaderboardDocs.docs[0].id, publicId);
  assert.equal(
    leaderboardDocs.docs.every((doc) => doc.id.startsWith('lb1_')),
    true,
  );
  assert.equal(
    leaderboardDocs.docs.some((doc) => doc.id.startsWith('old-')),
    false,
  );
});

test('deletion tombstone prevents economy and leaderboard state recreation', async () => {
  const database = db();
  const uid = 'emu-deleted';
  const publicLeaderboardId = leaderboardDocumentId(uid);
  const batch = database.batch();
  for (const collection of ACCOUNT_DOCUMENT_COLLECTIONS) {
    batch.set(database.collection(collection).doc(uid), {
      schemaVersion: 1,
      indiaAup: 5000000,
      displayName: 'Deleted Player',
    });
  }
  batch.set(
    database.collection(LEADERBOARD_COLLECTION).doc(publicLeaderboardId),
    {
      displayName: 'Deleted Player',
      rankScore: 100,
    },
  );
  batch.set(database.collection(ECONOMY_RECEIPTS_COLLECTION).doc('own'), {
    uid,
    eventId: 'before-deletion',
  });
  await batch.commit();

  await _deleteAccountData({ db: database, uid });

  const tombstone = await read(database, ACCOUNT_DELETIONS_COLLECTION, uid);
  assert.equal(tombstone.state, 'locked');
  for (const collection of ACCOUNT_DOCUMENT_COLLECTIONS) {
    assert.equal(await read(database, collection, uid), undefined);
  }
  assert.equal(
    await read(database, LEADERBOARD_COLLECTION, publicLeaderboardId),
    undefined,
  );
  assert.equal(
    await read(database, ECONOMY_RECEIPTS_COLLECTION, 'own'),
    undefined,
  );

  await assert.rejects(
    _walletForUser({ db: database, uid }),
    { code: 'account_deleted' },
  );
  await assert.rejects(
    _applyEconomyEvent({
      db: database,
      uid,
      body: {
        action: 'rewarded_ad',
        group: 'india',
        eventId: 'after-deletion',
      },
    }),
    { code: 'account_deleted' },
  );
  await assert.rejects(
    _syncLeaderboard({
      db: database,
      uid,
      auth: { uid, firebase: { sign_in_provider: 'password' } },
    }),
    { code: 'account_deleted' },
  );

  assert.equal(await read(database, SERVER_PROGRESS_COLLECTION, uid), undefined);
  assert.equal(await read(database, LEADERBOARD_COLLECTION, uid), undefined);
  assert.equal(
    await read(database, LEADERBOARD_COLLECTION, publicLeaderboardId),
    undefined,
  );
  assert.equal(
    await read(database, ECONOMY_RECEIPTS_COLLECTION, 'after-deletion'),
    undefined,
  );
});

test('concurrent wallet creation and account deletion always finish tombstoned', async () => {
  const database = db();

  for (let index = 0; index < 4; index += 1) {
    const uid = `emu-delete-race-${index}`;
    const outcomes = await Promise.allSettled([
      _walletForUser({ db: database, uid }),
      _deleteAccountData({ db: database, uid }),
    ]);

    assert.equal(outcomes[1].status, 'fulfilled');
    if (outcomes[0].status === 'rejected') {
      assert.equal(outcomes[0].reason.code, 'account_deleted');
    }
    assert.equal(
      (await read(database, ACCOUNT_DELETIONS_COLLECTION, uid)).state,
      'locked',
    );
    assert.equal(
      await read(database, SERVER_PROGRESS_COLLECTION, uid),
      undefined,
    );
  }
});
