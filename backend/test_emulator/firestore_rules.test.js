const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'ten-of-a-kind-poker';
let testEnv;

function requireFirestoreEmulator() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run with: ' +
        'firebase emulators:exec --project ten-of-a-kind-poker ' +
        '--only firestore "npm --prefix backend run test:emulator"',
    );
  }
}

function firestoreRules() {
  return fs.readFileSync(
    path.join(__dirname, '..', '..', 'firestore.rules'),
    'utf8',
  );
}

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function enableLegacyClientEconomyWrites() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'runtime_config/economy_authority'),
      { legacyClientWritesEnabled: true },
    );
  });
}

before(async () => {
  requireFirestoreEmulator();
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: firestoreRules(),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

test('authoritative economy writes deny clients by default', async () => {
  const alice = authedDb('rules-default-deny');
  await assertFails(
    setDoc(doc(alice, 'campaign_progress/rules-default-deny'), {
      schemaVersion: 1,
      cleared: ['sk:india:test:1'],
    }),
  );
  await assertFails(
    setDoc(doc(alice, 'aura_wallets/rules-default-deny'), {
      schemaVersion: 1,
      indiaAup: 1000,
    }),
  );
  await assertFails(
    setDoc(doc(alice, 'leaderboard/rules-default-deny'), {
      displayName: 'Rules Alice',
      auraMilli: 1,
      totalAup: 10000,
      activityScore: 1,
      rankScore: 1,
    }),
  );
  await assertFails(
    setDoc(doc(alice, 'server_progress/rules-default-deny'), {
      schemaVersion: 1,
      indiaAup: 1000,
    }),
  );
});

test('explicit migration flag allows validated campaign writes for self only', async () => {
  await enableLegacyClientEconomyWrites();
  const alice = authedDb('rules-alice');
  const selfRef = doc(alice, 'campaign_progress/rules-alice');
  const otherRef = doc(alice, 'campaign_progress/rules-bob');

  await assertSucceeds(
    setDoc(selfRef, {
      schemaVersion: 1,
      cleared: ['sk:india:test:1'],
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(selfRef, {
      mainEventsCleared: arrayUnion('me:india:test'),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(otherRef, {
      schemaVersion: 1,
      cleared: ['sk:india:test:1'],
    }),
  );

  const snap = await assertSucceeds(getDoc(selfRef));
  assert.equal(snap.exists(), true);
});

test('campaign document accepts the complete 401-fort and 40-title career', async () => {
  await enableLegacyClientEconomyWrites();
  const alice = authedDb('rules-career-complete');
  const selfRef = doc(alice, 'campaign_progress/rules-career-complete');
  const cleared = Array.from(
    { length: 401 },
    (_, index) => `sk:release:kingdom_${Math.trunc(index / 50)}:${index + 1}`,
  );
  const mainEventsCleared = Array.from(
    { length: 40 },
    (_, index) => `me:release:kingdom_${index + 1}`,
  );

  await assertSucceeds(
    setDoc(selfRef, {
      schemaVersion: 1,
      cleared,
      mainEventsCleared,
      updatedAt: serverTimestamp(),
    }),
  );

  const snap = await assertSucceeds(getDoc(selfRef));
  assert.equal(snap.data().cleared.length, 401);
  assert.equal(snap.data().mainEventsCleared.length, 40);
});

test('client can sync Spark wallet fields for self only', async () => {
  await enableLegacyClientEconomyWrites();
  const alice = authedDb('rules-alice');
  const progressRef = doc(alice, 'campaign_progress/rules-alice');
  const auraWalletRef = doc(alice, 'aura_wallets/rules-alice');
  const otherProgressRef = doc(alice, 'campaign_progress/rules-bob');

  await assertSucceeds(
    setDoc(progressRef, {
      schemaVersion: 1,
      cleared: ['sk:india:test:1'],
      indiaAup: 10000,
      internationalAup: 5000,
      awardedEventIds: ['sk:india:test:1'],
      registeredStarterGranted: true,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(progressRef, {
      cleared: arrayUnion('sk:india:test:2'),
      indiaAup: 12000,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(auraWalletRef, {
      schemaVersion: 1,
      indiaAup: 5000,
      awardedEventIds: ['legacy:award'],
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(otherProgressRef, {
      schemaVersion: 1,
      indiaAup: 10000,
    }),
  );
  await assertFails(updateDoc(progressRef, { indiaAup: 999999999 }));
});

test('leaderboard writes remain server-authoritative during legacy migration', async () => {
  await enableLegacyClientEconomyWrites();
  const alice = authedDb('rules-alice');
  const legacyOwnRef = doc(alice, 'leaderboard/rules-alice');
  const opaqueOwnRef = doc(
    alice,
    'leaderboard/lb1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  );

  for (const entryRef of [legacyOwnRef, opaqueOwnRef]) {
    await assertFails(setDoc(entryRef, {
      displayName: 'Rules Alice',
      auraMilli: 1000,
      totalAup: 10000000,
      activityScore: 7,
      matchesPlayed: 3,
      auraMilliPerMatch: 333,
      avgFinishPermille: 250,
      rankScore: 2000000000000,
      updatedAt: serverTimestamp(),
    }));
  }

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'leaderboard/lb1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      ),
      {
        displayName: 'Server Alice',
        auraMilli: 1000,
        totalAup: 10000000,
        activityScore: 7,
        rankScore: 2000000000000,
      },
    );
  });
  await assertFails(updateDoc(opaqueOwnRef, { auraMilli: 2000 }));
  await assertFails(deleteDoc(opaqueOwnRef));
});

test('public leaderboard list and direct reads remain available', async () => {
  const publicId =
    'lb1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `leaderboard/${publicId}`), {
      displayName: 'Active Player',
      auraMilli: 10,
      totalAup: 100000,
      activityScore: 1,
      rankScore: 100,
    });
  });

  const publicDb = testEnv.unauthenticatedContext().firestore();
  const snapshot = await assertSucceeds(
    getDocs(collection(publicDb, 'leaderboard')),
  );
  assert.equal(snapshot.docs.length, 1);
  assert.equal(snapshot.docs[0].id, publicId);
  const direct = await assertSucceeds(
    getDoc(doc(publicDb, `leaderboard/${publicId}`)),
  );
  assert.equal(direct.data().displayName, 'Active Player');
});

test('account deletion tombstones are private and block client recreation', async () => {
  const uid = 'rules-deleted';
  await enableLegacyClientEconomyWrites();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `account_deletions/${uid}`),
      { schemaVersion: 1, state: 'locked' },
    );
  });

  const deletedUser = authedDb(uid);
  const tombstoneRef = doc(deletedUser, `account_deletions/${uid}`);
  await assertFails(getDoc(tombstoneRef));
  await assertFails(setDoc(tombstoneRef, { state: 'removed' }));
  await assertFails(
    setDoc(doc(deletedUser, `users/${uid}`), {
      schemaVersion: 1,
      displayName: 'Recreated User',
    }),
  );
  await assertFails(
    setDoc(doc(deletedUser, `campaign_progress/${uid}`), {
      schemaVersion: 1,
      indiaAup: 10000,
    }),
  );
  await assertFails(
    setDoc(doc(deletedUser, `aura_wallets/${uid}`), {
      schemaVersion: 1,
      indiaAup: 10000,
    }),
  );
  await assertFails(
    setDoc(doc(deletedUser, `leaderboard/${uid}`), {
      displayName: 'Recreated User',
      auraMilli: 1,
      totalAup: 10000,
      activityScore: 1,
      rankScore: 1,
    }),
  );
});
