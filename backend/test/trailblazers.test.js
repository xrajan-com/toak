const assert = require('node:assert/strict');
const { test } = require('node:test');

const catalog = require('../src/economy/catalog.json');
const { FORT_TOTAL, fortsClearedCount } = require('../src/economy/catalog');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const { leaderboardDocumentId } = require('../src/leaderboard_identity');
const {
  LEADERBOARD_COLLECTION,
  TRAILBLAZERS_COLLECTION,
  USERS_COLLECTION,
  _refreshPublicBoards,
  _syncTrailblazers,
  _trailScore,
  trailStandingForUser,
} = require('../src/routes/leaderboard');
const { FakeFirestore } = require('./firestore_fake');

const FORT_IDS = Object.values(catalog.events)
  .filter((event) => event.kind === 'fort')
  .map((event) => event.id);
const TITLE_ID = Object.values(catalog.events)
  .find((event) => event.kind === 'main').id;

test('the journey has 500 forts, and only real, distinct forts count', () => {
  assert.equal(FORT_TOTAL, 500);
  assert.equal(fortsClearedCount(undefined), 0);
  assert.equal(
    fortsClearedCount([FORT_IDS[0], FORT_IDS[0], FORT_IDS[1], TITLE_ID, 'nope', 7]),
    2,
  );
  assert.equal(fortsClearedCount(FORT_IDS), 500);
});

test('forts cleared before their kingdom moved circuit still count, once', () => {
  // Australia moved from Rest of the World to Australasia; its forts kept
  // their numbers, so sk:international:australia:3 is today's
  // sk:oceania:australia:3.
  assert.equal(
    fortsClearedCount(['sk:international:australia:3']),
    1,
  );
  assert.equal(
    fortsClearedCount([
      'sk:international:australia:3',
      'sk:oceania:australia:3',
      'sk:euro:central_asia:1',
      'sk:international:central_asia:1',
      'sk:oceania:pacific:2',
    ]),
    3,
  );
});

test('more forts always ranks higher; Aura only breaks ties', () => {
  assert.ok(_trailScore(2, 0) > _trailScore(1, 100000));
  assert.ok(_trailScore(5, 2000) > _trailScore(5, 1000));
});

test('a player with forts gets a Trailblazers row with their count', async () => {
  const uid = 'trail-player';
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 5000000, cleared: FORT_IDS.slice(0, 3) },
    },
    [USERS_COLLECTION]: { [uid]: { displayName: 'Trail One' } },
  });

  const result = await _syncTrailblazers({ db, uid });
  const saved = db.dump(TRAILBLAZERS_COLLECTION, leaderboardDocumentId(uid));

  assert.equal(result.synced, true);
  assert.equal(saved.displayName, 'Trail One');
  assert.equal(saved.fortsCleared, 3);
  assert.equal(saved.trailScore, _trailScore(3, saved.auraMilli));
  assert.equal(saved.uid, undefined);
});

test('no forts means no row, and an old row is removed', async () => {
  const uid = 'no-forts';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 5000000, cleared: [TITLE_ID] },
    },
    [TRAILBLAZERS_COLLECTION]: {
      [publicId]: { displayName: 'Stale', fortsCleared: 1, trailScore: 1 },
    },
  });

  const result = await _syncTrailblazers({ db, uid });
  assert.deepEqual(result, { synced: false, removed: true, reason: 'no_forts' });
  assert.equal(db.dump(TRAILBLAZERS_COLLECTION, publicId), undefined);
});

test('a player with no name of their own never takes a place on the board', async () => {
  const uid = 'nameless';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 17) },
      named: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 2) },
    },
    [USERS_COLLECTION]: {
      [uid]: { email: 'someone@example.com', displayName: '  ' },
      named: { username: 'Peter Power' },
    },
    [TRAILBLAZERS_COLLECTION]: {
      [publicId]: { displayName: 'Player', fortsCleared: 17, trailScore: _trailScore(17, 0) },
    },
  });

  const result = await _syncTrailblazers({ db, uid });
  assert.deepEqual(result, { synced: false, removed: true, reason: 'no_name' });
  assert.equal(db.dump(TRAILBLAZERS_COLLECTION, publicId), undefined);

  const named = await _syncTrailblazers({ db, uid: 'named' });
  assert.equal(named.synced, true);
  assert.equal(
    db.dump(TRAILBLAZERS_COLLECTION, leaderboardDocumentId('named')).displayName,
    'Peter Power',
  );
});

test('a newcomer with more forts replaces the tenth row; fewer forts does not', async () => {
  const board = {};
  for (let forts = 1; forts <= 10; forts += 1) {
    board[leaderboardDocumentId(`incumbent-${forts}`)] = {
      displayName: `Incumbent ${forts}`,
      fortsCleared: forts,
      trailScore: _trailScore(forts, 0),
    };
  }
  const db = new FakeFirestore({
    [TRAILBLAZERS_COLLECTION]: board,
    [SERVER_PROGRESS_COLLECTION]: {
      tied: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 1) },
      newcomer: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 20) },
    },
    [USERS_COLLECTION]: {
      tied: { displayName: 'Tied Up' },
      newcomer: { displayName: 'Fort Runner' },
    },
  });

  const tied = await _syncTrailblazers({ db, uid: 'tied' });
  assert.equal(tied.reason, 'below_top_10');
  assert.equal(db.ids(TRAILBLAZERS_COLLECTION).length, 10);

  const promoted = await _syncTrailblazers({ db, uid: 'newcomer' });
  assert.equal(promoted.synced, true);
  assert.equal(db.ids(TRAILBLAZERS_COLLECTION).length, 10);
  assert.equal(
    db.dump(TRAILBLAZERS_COLLECTION, leaderboardDocumentId('incumbent-1')),
    undefined,
  );
  assert.equal(
    db.dump(TRAILBLAZERS_COLLECTION, leaderboardDocumentId('newcomer')).fortsCleared,
    20,
  );
});

test('one refresh updates both the Aura board and Trailblazers', async () => {
  const uid = 'both-boards';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, indiaAup: 2500000, cleared: FORT_IDS.slice(0, 2) },
    },
    [USERS_COLLECTION]: { [uid]: { displayName: 'Both' } },
  });

  const result = await _refreshPublicBoards({ db, uid });
  assert.equal(result.aura.synced, true);
  assert.equal(result.trailblazers.synced, true);
  assert.equal(db.dump(LEADERBOARD_COLLECTION, publicId).displayName, 'Both');
  assert.equal(db.dump(TRAILBLAZERS_COLLECTION, publicId).fortsCleared, 2);
});

test('standing: a named player sees their forts and place among named players', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      top: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 30) },
      nameless: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 20) },
      me: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 4) },
      behind: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 1) },
    },
    [USERS_COLLECTION]: {
      top: { displayName: 'Top Dog' },
      nameless: { email: 'x@example.com' },
      me: { displayName: 'Peter Power' },
      behind: { displayName: 'Behind' },
    },
  });
  // Fort clears keep the stored scores current.
  for (const uid of ['top', 'nameless', 'me', 'behind']) {
    await _syncTrailblazers({ db, uid });
  }

  const mine = await trailStandingForUser({ db, uid: 'me' });
  // The unnamed 20-fort player does not count against anyone.
  assert.deepEqual(mine, { fortsCleared: 4, fortTotal: 500, rank: 2, named: true });

  const theirs = await trailStandingForUser({ db, uid: 'nameless' });
  // Without a name: where they would stand once they set one.
  assert.deepEqual(theirs, { fortsCleared: 20, fortTotal: 500, rank: 2, named: false });
});

test('standing: setting a name puts the player on the board right away', async () => {
  const uid = 'renamed';
  const publicId = leaderboardDocumentId(uid);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 5) },
    },
    [USERS_COLLECTION]: { [uid]: { email: 'r@example.com' } },
  });
  await _syncTrailblazers({ db, uid });
  assert.equal(db.dump(TRAILBLAZERS_COLLECTION, publicId), undefined);

  // The player sets their name in the app; the next look syncs the board.
  await db.collection(USERS_COLLECTION).doc(uid).set(
    { displayName: 'New Name' },
    { merge: true },
  );
  const standing = await trailStandingForUser({ db, uid });
  assert.equal(standing.named, true);
  assert.equal(standing.rank, 1);
  assert.equal(db.dump(TRAILBLAZERS_COLLECTION, publicId).displayName, 'New Name');
});

test('standing: no forts means no place, and an old wallet heals itself', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      fresh: { schemaVersion: 1, cleared: [] },
      // Saved before trail scores existed: no trailScore stored yet.
      legacy: { schemaVersion: 1, cleared: FORT_IDS.slice(0, 3) },
    },
    [USERS_COLLECTION]: {
      fresh: { displayName: 'Fresh' },
      legacy: { displayName: 'Legacy' },
    },
  });

  assert.deepEqual(
    await trailStandingForUser({ db, uid: 'fresh' }),
    { fortsCleared: 0, fortTotal: 500, rank: null, named: true },
  );
  const legacy = await trailStandingForUser({ db, uid: 'legacy' });
  assert.equal(legacy.rank, 1);
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'legacy');
  assert.equal(saved.trailScore, _trailScore(3, 0));
  assert.equal(saved.trailRankScore, saved.trailScore);
  assert.equal(saved.trailName, 'Legacy');
  assert.ok(db.dump(TRAILBLAZERS_COLLECTION, leaderboardDocumentId('legacy')));
});
