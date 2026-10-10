const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  CLIENT_WALLET_COLLECTION,
  LEGACY_PROGRESS_COLLECTION,
  migrateLegacyWallet,
} = require('../scripts/migrate_legacy_wallets');
const { totalAup } = require('../src/economy/progress');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const { walletForUser } = require('../src/economy/wallet');
const {
  ACCOUNT_DELETIONS_COLLECTION,
} = require('../src/security/firebase_auth');
const { FakeFirestore } = require('./firestore_fake');

test('a dry run reports a migration and writes nothing', async () => {
  const db = new FakeFirestore({
    [LEGACY_PROGRESS_COLLECTION]: {
      player1: { schemaVersion: 1, awardedEventIds: ['legacy:event'] },
    },
  });

  const result = await migrateLegacyWallet({ db, uid: 'player1' });

  assert.equal(result.outcome, 'migrated');
  assert.equal(db.dump(SERVER_PROGRESS_COLLECTION, 'player1'), undefined);
});

test('pre-server progress becomes a migrated server wallet; the starter comes once, on open', async () => {
  const db = new FakeFirestore({
    [LEGACY_PROGRESS_COLLECTION]: {
      player1: { schemaVersion: 1, awardedEventIds: ['legacy:event'] },
    },
  });

  const applied = await migrateLegacyWallet({ db, uid: 'player1', apply: true });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(applied.outcome, 'migrated');
  assert.equal(saved.legacyMigrationVersion, 1);
  assert.equal(saved.migratedFrom, LEGACY_PROGRESS_COLLECTION);
  assert.deepEqual(saved.awardedEventIds, ['legacy:event']);
  assert.equal(
    (await migrateLegacyWallet({ db, uid: 'player1', apply: true })).outcome,
    'current',
  );

  const opened = await walletForUser({ db, uid: 'player1' });
  assert.equal(opened.progress.registeredStarterGranted, true);
  assert.equal(totalAup(opened.progress), 10000);
});

test('the dedicated version-2 client wallet wins over campaign_progress', async () => {
  const db = new FakeFirestore({
    [CLIENT_WALLET_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        walletStorageVersion: 2,
        indiaAup: 45000,
        registeredStarterGranted: true,
      },
    },
    [LEGACY_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 1000,
        registeredStarterGranted: true,
      },
    },
  });

  await migrateLegacyWallet({ db, uid: 'player1', apply: true });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(saved.indiaAup, 45000);
  assert.equal(
    saved.migratedFrom,
    `${LEGACY_PROGRESS_COLLECTION}+${CLIENT_WALLET_COLLECTION}`,
  );
  assert.deepEqual(saved.cleared, []);
});

test('a server wallet stuck below the marker is brought up to it', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 3000,
        registeredStarterGranted: true,
        legacyMigrationVersion: 0,
      },
    },
  });

  const result = await migrateLegacyWallet({ db, uid: 'player1', apply: true });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(result.outcome, 'migrated');
  assert.equal(saved.legacyMigrationVersion, 1);
  assert.equal(saved.indiaAup, 3000);
});

test('a balance that disagrees with the server is left for a person', async () => {
  const server = {
    schemaVersion: 1,
    indiaAup: 5000,
    matchesPlayed: 3,
    registeredStarterGranted: true,
    legacyMigrationVersion: 0,
  };
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: { player1: server },
    [LEGACY_PROGRESS_COLLECTION]: {
      player1: { schemaVersion: 1, indiaAup: 9000 },
    },
  });

  const result = await migrateLegacyWallet({ db, uid: 'player1', apply: true });

  assert.equal(result.outcome, 'conflict');
  assert.deepEqual(db.dump(SERVER_PROGRESS_COLLECTION, 'player1'), server);
});

test('deleted accounts and players with nothing to migrate are skipped', async () => {
  const db = new FakeFirestore({
    [ACCOUNT_DELETIONS_COLLECTION]: {
      gone: { schemaVersion: 1, state: 'locked' },
    },
    [LEGACY_PROGRESS_COLLECTION]: {
      gone: { schemaVersion: 1, indiaAup: 9000 },
    },
  });

  assert.equal(
    (await migrateLegacyWallet({ db, uid: 'gone', apply: true })).outcome,
    'deleted',
  );
  assert.equal(
    (await migrateLegacyWallet({ db, uid: 'nobody', apply: true })).outcome,
    'none',
  );
  assert.equal(db.dump(SERVER_PROGRESS_COLLECTION, 'gone'), undefined);
});
