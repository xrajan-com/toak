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
    [USERS_COLLECTION]: { newcomer: { displayName: 'Fort Runner' } },
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
