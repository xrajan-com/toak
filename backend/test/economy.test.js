const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { test } = require('node:test');

const economyCatalog = require('../src/economy/catalog.json');
const {
  ECONOMY_CATALOG_550_EURASIA11_VERSION,
  ECONOMY_CATALOG_550_VERSION,
  ECONOMY_CATALOG_VERSION,
  SUPPORTED_ECONOMY_CATALOG_VERSIONS,
  campaignEvent,
} = require('../src/economy/catalog');
const {
  MAX_AUP_PER_CIRCUIT,
  MAX_CAMPAIGN_WIN_AUP,
} = require('../src/economy/constants');
const {
  entryReservationStatus,
  reserveEntry,
  transitionEntryReservation,
} = require('../src/economy/entries');
const { applyEconomyEvent } = require('../src/economy/events');
const { baseProgress, snapshot } = require('../src/economy/progress');
const { rankForUser } = require('../src/economy/rank');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const { walletForUser } = require('../src/economy/wallet');
const { catalogVersionForRequest } = require('../src/routes/economy');
const { FakeFirestore } = require('./firestore_fake');
const {
  ACCOUNT_DELETIONS_COLLECTION,
} = require('../src/security/firebase_auth');

const FREE_FORT = 'sk:international:arabia:3';
const FREE_FORT_WIN = economyCatalog.events[FREE_FORT].payouts[0];

function totalAup(progress) {
  return progress.indiaAup +
    progress.internationalAup +
    progress.euroAup +
    progress.oceaniaAup +
    progress.northAmericaAup;
}

test('catalog compatibility version is bound to the exact catalog content', () => {
  const calculatedHash = crypto
    .createHash('sha256')
    .update(JSON.stringify({
      schemaVersion: economyCatalog.schemaVersion,
      eventCount: economyCatalog.eventCount,
      events: economyCatalog.events,
    }))
    .digest('hex');

  assert.equal(economyCatalog.contentHash, calculatedHash);
  assert.equal(
    ECONOMY_CATALOG_VERSION,
    `v1:550:${calculatedHash}`,
  );
  for (const event of Object.values(economyCatalog.events)) {
    assert.equal(Number.isInteger(event.maxPlayers), true, event.id);
    assert.equal(event.maxPlayers >= 2 && event.maxPlayers <= 10, true, event.id);
  }
});

test('catalog negotiation serves recent builds their own catalog and everyone else the live one', () => {
  const versionFor = (header) => catalogVersionForRequest({ get: () => header });

  assert.equal(versionFor(undefined), ECONOMY_CATALOG_VERSION);
  assert.equal(versionFor(ECONOMY_CATALOG_VERSION), ECONOMY_CATALOG_VERSION);
  assert.equal(versionFor(ECONOMY_CATALOG_550_VERSION), ECONOMY_CATALOG_550_VERSION);
  assert.equal(
    versionFor(ECONOMY_CATALOG_550_EURASIA11_VERSION),
    ECONOMY_CATALOG_550_EURASIA11_VERSION,
  );
  // Retired with builds from before August 2026: they now see a mismatch
  // and ask the player to update.
  assert.equal(
    versionFor('v1:494:941a25a55ae5bb3d9d1fad40988b71b60d42480c2a9c16b8f49bd82889b0ea60'),
    ECONOMY_CATALOG_VERSION,
  );
  assert.equal(
    versionFor('v1:441:642c58b38694044f869bad6873e5c76df042c87e4abc8be3db29ebaea2e802fb'),
    ECONOMY_CATALOG_VERSION,
  );
  assert.equal(versionFor('v1:999:unknown'), ECONOMY_CATALOG_VERSION);
  assert.deepEqual(SUPPORTED_ECONOMY_CATALOG_VERSIONS, [
    ECONOMY_CATALOG_VERSION,
    ECONOMY_CATALOG_550_EURASIA11_VERSION,
    ECONOMY_CATALOG_550_VERSION,
  ]);
});

test('builds pinned to the eleven-kingdom Eurasia keep their Central Asia events', () => {
  assert.equal(
    SUPPORTED_ECONOMY_CATALOG_VERSIONS.includes(
      ECONOMY_CATALOG_550_EURASIA11_VERSION,
    ),
    true,
  );
  assert.equal(
    catalogVersionForRequest({
      get: () => ECONOMY_CATALOG_550_EURASIA11_VERSION,
    }),
    ECONOMY_CATALOG_550_EURASIA11_VERSION,
  );
  const pinned = campaignEvent(
    'me:euro:central_asia',
    ECONOMY_CATALOG_550_EURASIA11_VERSION,
  );
  assert.equal(pinned.kingdom, 'Central Asia');
  assert.equal(pinned.requiredFortIds.length, 11);
});

test('a stored entry without a catalog version settles under the live catalog', () => {
  const progress = baseProgress({
    entryReservations: [{
      attemptId: 'pre-catalog-version-entry',
      campaignId: FREE_FORT,
      group: 'international',
      amount: 0,
      status: 'committed',
    }],
  });

  assert.equal(progress.entryReservations[0].catalogVersion, ECONOMY_CATALOG_VERSION);
});

test('a snapshot shows every circuit as stored, with the catalog it was priced by', () => {
  const progress = baseProgress({
    indiaAup: 250000000,
    internationalAup: 250000000,
    euroAup: 250000000,
    oceaniaAup: 250000000,
  });
  const shown = snapshot(progress, ECONOMY_CATALOG_550_VERSION);

  assert.equal(shown.catalogVersion, ECONOMY_CATALOG_550_VERSION);
  assert.equal(totalAup(shown), 1000000000);
  for (const field of [
    'indiaAup',
    'internationalAup',
    'euroAup',
    'oceaniaAup',
    'northAmericaAup',
  ]) {
    assert.equal(shown[field], 200000000, field);
  }
});

test('a deletion tombstone blocks every economy transaction from recreating state', async () => {
  const uid = 'deleted-economy-user';
  const db = new FakeFirestore({
    [ACCOUNT_DELETIONS_COLLECTION]: {
      [uid]: { schemaVersion: 1, state: 'locked' },
    },
  });
  const calls = [
    () => walletForUser({ db, uid }),
    () => reserveEntry({
      db,
      uid,
      body: {
        campaignId: Object.values(economyCatalog.events)[0].id,
        attemptId: 'deleted-attempt',
      },
    }),
    () => transitionEntryReservation({
      db,
      uid,
      body: { attemptId: 'deleted-attempt' },
      transition: 'commit',
    }),
    () => entryReservationStatus({
      db,
      uid,
      attemptId: 'deleted-attempt',
    }),
    () => applyEconomyEvent({
      db,
      uid,
      body: {
        action: 'rewarded_ad',
        group: 'india',
        eventId: 'deleted-event',
      },
    }),
  ];

  for (const call of calls) {
    await assert.rejects(call, { code: 'account_deleted' });
  }
  assert.equal(db.dump(SERVER_PROGRESS_COLLECTION, uid), undefined);
  assert.deepEqual(db.ids('economy_receipts'), []);
});

test('client-asserted rewarded ads never mint AUP', async () => {
  const uid = 'rewarded-ad-client-assertion';
  const db = new FakeFirestore();

  const result = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'rewarded_ad',
      group: 'india',
      eventId: 'unverified-ad-view',
    },
  });

  assert.equal(result.accepted, false);
  assert.equal(result.delta, 0);
  assert.equal(result.reason, 'rewarded_ad_verification_required');
  assert.equal(result.progress.indiaAup, 2000);
  assert.equal(result.progress.rewardedAdDayCount, 0);
});

async function reserveAndCommit({
  db,
  uid,
  campaignId,
  attemptId,
}) {
  const reserved = await reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId },
  });
  assert.equal(reserved.accepted, true);
  const committed = await transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'commit',
  });
  assert.equal(committed.accepted, true);
  return { reserved, committed };
}

test('an affordable paid fort can be reserved without clearing predecessors',
  async () => {
    const uid = 'sequence-independent-fort-player';
    const campaignId = 'sk:international:pacific:1';
    const event = economyCatalog.events[campaignId];
    assert.equal(event.kind, 'fort');
    assert.equal(event.entryFee > 0, true);
    assert.equal(event.predecessorId, null);

    const db = new FakeFirestore({
      [SERVER_PROGRESS_COLLECTION]: {
        [uid]: {
          schemaVersion: 1,
          internationalAup: event.entryFee + 1000,
          registeredStarterGranted: true,
          cleared: [],
        },
      },
    });
    const reserved = await reserveEntry({
      db,
      uid,
      body: { campaignId, attemptId: 'out-of-sequence-paid-entry' },
    });

    assert.equal(reserved.accepted, true, reserved.reason);
    assert.equal(reserved.reservation.amount, event.entryFee);
    assert.equal(reserved.progress.internationalAup, 1000);
  });

test('economy event applies inside a transaction and persists the result', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 5000,
        registeredStarterGranted: true,
      },
    },
  });

  const result = await applyEconomyEvent({
    db,
    uid: 'player1',
    body: {
      action: 'match_completed',
      heroWon: false,
      totalPlayers: 6,
      finishRank: 3,
      eventId: 'quick-game:1',
    },
  });

  assert.equal(db.transactionCount, 1);
  assert.equal(result.accepted, true);
  // A loss costs one thousandth of the wallet.
  assert.equal(result.delta, -5);

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');
  assert.equal(saved.indiaAup, 4995);
  assert.equal(saved.matchesPlayed, 1);
  assert.deepEqual(saved.appliedEventIds, ['quick-game:1']);
});

test('backend limits match the 200M-per-circuit client economy', () => {
  const progress = baseProgress({
    indiaAup: MAX_AUP_PER_CIRCUIT,
    internationalAup: MAX_AUP_PER_CIRCUIT,
  });

  assert.equal(MAX_AUP_PER_CIRCUIT, 200000000);
  assert.equal(MAX_CAMPAIGN_WIN_AUP, 25000000);
  assert.equal(progress.indiaAup, 200000000);
  assert.equal(progress.internationalAup, 200000000);
});

test('legacy circuit overflow moves into North America without changing total Aura', () => {
  const progress = baseProgress({
    indiaAup: 250000000,
    internationalAup: 250000000,
    euroAup: 250000000,
    oceaniaAup: 250000000,
  });

  assert.equal(progress.indiaAup, 200000000);
  assert.equal(progress.internationalAup, 200000000);
  assert.equal(progress.euroAup, 200000000);
  assert.equal(progress.oceaniaAup, 200000000);
  assert.equal(progress.northAmericaAup, 200000000);
  assert.equal(totalAup(progress), 1000000000);
  assert.deepEqual(baseProgress(progress), progress);
});

test('a legitimate title-match reward above 10M is credited in full', async () => {
  const main = economyCatalog.events['me:euro:britain_ireland'];
  assert.equal(main.payouts[0] > 10000000, true);
  const uid = 'title-winner';
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: {
        schemaVersion: 1,
        euroAup: main.entryFee,
        registeredStarterGranted: true,
        cleared: main.requiredFortIds,
      },
    },
  });

  await reserveAndCommit({ db, uid, campaignId: main.id, attemptId: 'title:1' });
  const result = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_result',
      campaignId: main.id,
      entryAttemptId: 'title:1',
      placement: 1,
      totalPlayers: main.maxPlayers,
      eventId: 'title-result:1',
    },
  });

  assert.equal(result.accepted, true, result.reason);
  assert.equal(result.payoutDelta, main.payouts[0]);
  assert.equal(result.progress.euroAup, main.payouts[0]);
});

test('an entry the player cannot afford is refused without a deduction', async () => {
  const campaignId = 'sk:euro:balkans_mediterranean:1';
  const event = economyCatalog.events[campaignId];
  assert.equal(event.entryFee > 0, true);
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        euroAup: event.entryFee - 1,
        registeredStarterGranted: true,
      },
    },
  });

  const result = await reserveEntry({
    db,
    uid: 'player1',
    body: { campaignId, attemptId: 'too-poor:1' },
  });

  assert.equal(result.accepted, false);
  assert.equal(result.reason, 'insufficient_funds');
  assert.equal(result.progress.euroAup, event.entryFee - 1);
  assert.equal(
    db.dump(SERVER_PROGRESS_COLLECTION, 'player1').euroAup,
    event.entryFee - 1,
  );
});

test('client-priced entry fees are refused; entries go through a reservation', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 5000,
        registeredStarterGranted: true,
      },
    },
  });

  const result = await applyEconomyEvent({
    db,
    uid: 'player1',
    body: {
      action: 'entry_fee',
      group: 'india',
      amount: 2000,
      eventId: 'fee:india:2000:1',
    },
  });

  assert.equal(result.accepted, false);
  assert.equal(result.reason, 'entry_reservation_required');
  assert.equal(result.progress.indiaAup, 5000);
  assert.deepEqual(db.ids('economy_receipts'), []);
});

test('duplicate event ids are idempotent', async () => {
  const db = new FakeFirestore();
  const uid = 'player1';
  await reserveAndCommit({ db, uid, campaignId: FREE_FORT, attemptId: 'dup:1' });
  const body = {
    action: 'campaign_win',
    campaignId: FREE_FORT,
    entryAttemptId: 'dup:1',
    placement: 1,
    eventId: 'campaign:dup:final',
  };

  const first = await applyEconomyEvent({ db, uid, body });
  const afterFirst = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  const second = await applyEconomyEvent({ db, uid, body });
  const afterSecond = db.dump(SERVER_PROGRESS_COLLECTION, uid);

  assert.equal(first.accepted, true);
  assert.equal(first.duplicate, false);
  assert.equal(first.delta, FREE_FORT_WIN);
  assert.equal(second.accepted, true);
  assert.equal(second.duplicate, true);
  assert.equal(second.delta, 0);
  assert.equal(afterFirst.internationalAup, afterSecond.internationalAup);
  assert.deepEqual(afterSecond.awardedEventIds, [FREE_FORT]);
});

test('a settled entry pays once, whatever eventId it is reported under', async () => {
  const db = new FakeFirestore();
  const uid = 'player1';
  await reserveAndCommit({ db, uid, campaignId: FREE_FORT, attemptId: 'replay:1' });
  const body = {
    action: 'campaign_win',
    campaignId: FREE_FORT,
    entryAttemptId: 'replay:1',
    placement: 1,
  };

  const first = await applyEconomyEvent({
    db,
    uid,
    body: { ...body, eventId: 'win:replay:1:a' },
  });
  const sameEntryNewEvent = await applyEconomyEvent({
    db,
    uid,
    body: { ...body, eventId: 'win:replay:1:b' },
  });

  assert.equal(first.delta, FREE_FORT_WIN);
  assert.equal(sameEntryNewEvent.accepted, true);
  assert.equal(sameEntryNewEvent.reason, 'duplicate_settlement');
  assert.equal(sameEntryNewEvent.delta, 0);
  assert.equal(
    db.dump(SERVER_PROGRESS_COLLECTION, uid).internationalAup,
    2000 + FREE_FORT_WIN,
  );
});

test('fort replays have no play-count limit and history stays bounded', async () => {
  const db = new FakeFirestore();
  const uid = 'player1';
  const replays = 501;

  for (let replay = 1; replay <= replays; replay += 1) {
    const attemptId = `replay-entry:${replay}`;
    await reserveAndCommit({ db, uid, campaignId: FREE_FORT, attemptId });
    const result = await applyEconomyEvent({
      db,
      uid,
      body: {
        action: 'campaign_win',
        campaignId: FREE_FORT,
        entryAttemptId: attemptId,
        placement: 1,
        eventId: `replay-win:${replay}`,
      },
    });
    assert.equal(result.accepted, true, result.reason);
    assert.equal(result.delta, FREE_FORT_WIN);
  }

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(
    saved.internationalAup,
    Math.min(2000 + (replays * FREE_FORT_WIN), MAX_AUP_PER_CIRCUIT),
  );
  assert.equal(saved.appliedEventIds.length, 500);
  assert.equal(saved.entryReservations.length, 40);
  assert.deepEqual(saved.awardedEventIds, [FREE_FORT]);
});

test('catalog-backed entry and win ignore client fee, group, and prize claims', async () => {
  const db = new FakeFirestore();
  const uid = 'catalog-player';
  const freeFort = 'sk:international:arabia:3';
  const attemptId = 'entry:central-asia-free:1';

  const directWin = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_win',
      group: 'india',
      amount: MAX_CAMPAIGN_WIN_AUP,
      campaignId: freeFort,
      placement: 1,
      eventId: 'forged-win-without-entry',
    },
  });
  assert.equal(directWin.accepted, false);
  assert.equal(directWin.reason, 'committed_entry_required');
  assert.equal(db.dump(SERVER_PROGRESS_COLLECTION, uid), undefined);

  const { reserved } = await reserveAndCommit({
    db,
    uid,
    campaignId: freeFort,
    attemptId,
  });
  assert.equal(reserved.reservation.amount, 0);
  assert.equal(reserved.reservation.group, 'international');

  const win = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_win',
      // These values are deliberately forged. The catalog and placement
      // determine the credited circuit and payout.
      group: 'india',
      amount: MAX_CAMPAIGN_WIN_AUP,
      campaignId: freeFort,
      entryAttemptId: attemptId,
      placement: 1,
      eventId: 'catalog-win:central-asia-free:1',
    },
  });
  assert.equal(win.accepted, true);
  assert.equal(win.delta, 143400);

  const afterWin = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(afterWin.indiaAup, 2000);
  assert.equal(afterWin.internationalAup, 145400);
  assert.deepEqual(afterWin.cleared, [freeFort]);
  assert.equal(afterWin.entryReservations[0].status, 'settled');

  const paid = await reserveEntry({
    db,
    uid,
    body: {
      campaignId: 'sk:international:pacific:1',
      attemptId: 'entry:central-asia-paid:1',
      amount: 1,
      group: 'india',
    },
  });
  assert.equal(paid.accepted, true);
  assert.equal(paid.reservation.amount, 68000);
  assert.equal(paid.reservation.group, 'international');
  assert.equal(paid.delta, -68000);
  assert.equal(paid.progress.internationalAup, 77400);
});

test('secure catalog reservations allow unlimited fort replays with unique attempts', async () => {
  const db = new FakeFirestore();
  const uid = 'secure-replay-player';
  const campaignId = 'sk:international:arabia:3';

  for (let replay = 1; replay <= 5; replay += 1) {
    const attemptId = `entry:secure-replay:${replay}`;
    await reserveAndCommit({ db, uid, campaignId, attemptId });
    const win = await applyEconomyEvent({
      db,
      uid,
      body: {
        action: 'campaign_win',
        campaignId,
        entryAttemptId: attemptId,
        placement: 1,
        eventId: `win:secure-replay:${replay}`,
      },
    });
    assert.equal(win.accepted, true);
    assert.equal(win.delta, 143400);
  }

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(saved.internationalAup, 2000 + (5 * 143400));
  assert.deepEqual(saved.cleared, [campaignId]);
  assert.equal(
    saved.entryReservations.filter((entry) => entry.status === 'settled').length,
    5,
  );
});

test('committed entry recovery is delayed, idempotent, and penalized once', async () => {
  const uid = 'recovery-player';
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      [uid]: {
        schemaVersion: 1,
        internationalAup: 100000,
        registeredStarterGranted: true,
        cleared: ['sk:international:arabia:3'],
      },
    },
  });
  const campaignId = 'sk:international:pacific:1';
  const attemptId = 'entry:recovery:1';
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const tooSoon = await transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'recover',
  });
  assert.equal(tooSoon.accepted, false);
  assert.equal(tooSoon.reason, 'recovery_not_ready');
  assert.equal(tooSoon.progress.internationalAup, 32000);

  const stored = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  stored.entryReservations[0].updatedAtMs = 1;
  await db.collection(SERVER_PROGRESS_COLLECTION).doc(uid).set(stored);

  const recovered = await transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'recover',
  });
  assert.equal(recovered.accepted, true);
  assert.equal(recovered.duplicate, false);
  assert.equal(recovered.reason, 'abandoned_entry_recovered');
  assert.equal(recovered.progress.internationalAup, 99700);
  assert.equal(recovered.progress.matchesPlayed, 1);
  assert.equal(recovered.progress.abandonedGames, 1);

  const duplicate = await transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'recover',
  });
  assert.equal(duplicate.accepted, true);
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.delta, 0);
  assert.equal(duplicate.progress.internationalAup, 99700);
  assert.equal(duplicate.progress.matchesPlayed, 1);
  assert.equal(duplicate.progress.abandonedGames, 1);
});

test('only one active entry is allowed and terminal history cannot replace it', async () => {
  const db = new FakeFirestore();
  const uid = 'single-active-player';
  const campaignId = 'sk:international:arabia:3';
  const firstAttempt = 'entry:single-active:1';

  const first = await reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: firstAttempt },
  });
  assert.equal(first.accepted, true);

  const conflict = await reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:2' },
  });
  assert.equal(conflict.accepted, false);
  assert.equal(conflict.reason, 'active_entry_conflict');
  assert.equal(conflict.reservation.attemptId, firstAttempt);

  await transitionEntryReservation({
    db,
    uid,
    body: { attemptId: firstAttempt },
    transition: 'commit',
  });
  const committedConflict = await reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:3' },
  });
  assert.equal(committedConflict.accepted, false);
  assert.equal(committedConflict.reservation.status, 'committed');

  await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_result',
      campaignId,
      entryAttemptId: firstAttempt,
      placement: 1,
      totalPlayers: economyCatalog.events[campaignId].maxPlayers,
      eventId: 'result:single-active:1',
    },
  });
  const afterSettlement = await reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:4' },
  });
  assert.equal(afterSettlement.accepted, true);
});

test('campaign result settles unpaid ranks, records stats once, and never refunds a loss', async () => {
  const db = new FakeFirestore();
  const uid = 'loss-player';
  const campaignId = 'sk:international:arabia:3';
  const attemptId = 'entry:loss:1';
  const totalPlayers = economyCatalog.events[campaignId].maxPlayers;
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const body = {
    action: 'campaign_result',
    campaignId,
    entryAttemptId: attemptId,
    placement: 4,
    totalPlayers,
    eventId: 'result:loss:1',
  };
  const result = await applyEconomyEvent({ db, uid, body });
  const duplicate = await applyEconomyEvent({ db, uid, body });

  assert.equal(result.accepted, true);
  assert.equal(result.payoutDelta, 0);
  assert.equal(result.clearRecorded, false);
  assert.equal(result.matchRecorded, true);
  assert.equal(result.progress.matchesPlayed, 1);
  assert.equal(result.progress.entryReservations[0].status, 'settled');
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.progress.matchesPlayed, 1);

  const recovery = await transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'recover',
  });
  assert.equal(recovery.accepted, false);
  assert.equal(recovery.reason, 'entry_already_settled');
});

test('campaign results reject forged table sizes and use catalog size for stats', async () => {
  const db = new FakeFirestore();
  const uid = 'table-size-forgery-player';
  const campaignId = 'sk:international:arabia:3';
  const attemptId = 'entry:table-size-forgery:1';
  const authoritativePlayers = economyCatalog.events[campaignId].maxPlayers;
  assert.equal(authoritativePlayers, 6);
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const forged = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_result',
      campaignId,
      entryAttemptId: attemptId,
      placement: 4,
      totalPlayers: 10,
      eventId: 'result:table-size-forgery:1',
    },
  });
  assert.equal(forged.accepted, false);
  assert.equal(forged.reason, 'invalid_total_players');
  assert.equal(forged.progress.matchesPlayed, 0);
  assert.equal(forged.progress.finishPermilleSum, 0);
  assert.equal(forged.progress.entryReservations[0].status, 'committed');

  const valid = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_result',
      campaignId,
      entryAttemptId: attemptId,
      placement: 4,
      totalPlayers: authoritativePlayers,
      eventId: 'result:table-size-valid:1',
    },
  });
  assert.equal(valid.accepted, true);
  assert.equal(valid.progress.matchesPlayed, 1);
  assert.equal(valid.progress.finishPermilleSum, 600);
  assert.equal(valid.progress.entryReservations[0].status, 'settled');
});

test('campaign abandonment is always recorded at the catalog last place', async () => {
  const db = new FakeFirestore();
  const uid = 'abandon-placement-forgery-player';
  const campaignId = 'sk:international:arabia:3';
  const attemptId = 'entry:abandon-placement-forgery:1';
  const totalPlayers = economyCatalog.events[campaignId].maxPlayers;
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const forged = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_abandoned',
      campaignId,
      entryAttemptId: attemptId,
      placement: 1,
      totalPlayers,
      eventId: 'abandon:placement-forgery:1',
    },
  });
  assert.equal(forged.accepted, false);
  assert.equal(forged.reason, 'invalid_placement');
  assert.equal(forged.progress.matchesPlayed, 0);

  const valid = await applyEconomyEvent({
    db,
    uid,
    body: {
      action: 'campaign_abandoned',
      campaignId,
      entryAttemptId: attemptId,
      placement: totalPlayers,
      totalPlayers,
      eventId: 'abandon:placement-valid:1',
    },
  });
  assert.equal(valid.accepted, true);
  assert.equal(valid.progress.matchesPlayed, 1);
  assert.equal(valid.progress.abandonedGames, 1);
  assert.equal(valid.progress.finishPermilleSum, 1000);
});

test('fresh authoritative wallet can clear all 500 forts and win all 50 titles', async () => {
  const db = new FakeFirestore();
  const uid = 'full-career-player';
  const events = Object.values(economyCatalog.events);
  const mains = events.filter((event) => event.kind === 'main');
  let attemptCounter = 0;

  for (const main of mains) {
    const remaining = events.filter(
      (event) =>
        event.kind === 'fort' &&
        event.group === main.group &&
        event.kingdom === main.kingdom,
    );
    // A new wallet starts with a small balance, so play the free fort first and
    // then choose any currently affordable paid fort. This is an affordability
    // order, not a predecessor chain.
    remaining.sort((a, b) => {
      if (a.entryFee === 0) return -1;
      if (b.entryFee === 0) return 1;
      if (a.entryFee !== b.entryFee) return a.entryFee - b.entryFee;
      return b.id.localeCompare(a.id);
    });
    const freeEvent = remaining.find((event) => event.entryFee === 0);
    assert.notEqual(freeEvent, undefined, `Missing free fort for ${main.id}`);
    while (remaining.length > 0) {
      const event = remaining.shift();
      assert.equal(event.predecessorId, null, event.id);
      let grindCount = 0;
      const groupBalanceField = `${event.group}Aup`;
      while (
        (db.dump(SERVER_PROGRESS_COLLECTION, uid)?.[groupBalanceField] ?? 0) <
        event.entryFee
      ) {
        grindCount += 1;
        assert.ok(grindCount < 1000, `Cannot grind entry for ${event.id}`);
        attemptCounter += 1;
        const grindAttempt = `career-grind-entry:${attemptCounter}`;
        await reserveAndCommit({
          db,
          uid,
          campaignId: freeEvent.id,
          attemptId: grindAttempt,
        });
        const grindResult = await applyEconomyEvent({
          db,
          uid,
          body: {
            action: 'campaign_result',
            campaignId: freeEvent.id,
            entryAttemptId: grindAttempt,
            placement: 1,
            totalPlayers: freeEvent.maxPlayers,
            eventId: `career-grind-result:${attemptCounter}`,
          },
        });
        assert.equal(grindResult.accepted, true, grindResult.reason);
      }
      attemptCounter += 1;
      const attemptId = `career-entry:${attemptCounter}`;
      const { reserved } = await reserveAndCommit({
        db,
        uid,
        campaignId: event.id,
        attemptId,
      });
      assert.equal(
        reserved.reservation.amount,
        event.entryFee,
        `Catalog fee mismatch for ${event.id}`,
      );
      const result = await applyEconomyEvent({
        db,
        uid,
        body: {
          action: 'campaign_result',
          campaignId: event.id,
          entryAttemptId: attemptId,
          placement: 1,
          totalPlayers: event.maxPlayers,
          eventId: `career-result:${attemptCounter}`,
        },
      });
      assert.equal(result.accepted, true, result.reason);
      assert.equal(result.clearRecorded, true);
    }

    attemptCounter += 1;
    const mainAttempt = `career-entry:${attemptCounter}`;
    await reserveAndCommit({
      db,
      uid,
      campaignId: main.id,
      attemptId: mainAttempt,
    });
    const title = await applyEconomyEvent({
      db,
      uid,
      body: {
        action: 'campaign_result',
        campaignId: main.id,
        entryAttemptId: mainAttempt,
        placement: 1,
        totalPlayers: main.maxPlayers,
        eventId: `career-result:${attemptCounter}`,
      },
    });
    assert.equal(title.accepted, true, title.reason);
    assert.equal(title.clearRecorded, true);
  }

  const completed = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(completed.cleared.length, 500);
  assert.equal(completed.mainEventsCleared.length, 50);

  const freeForts = events.filter(
    (event) => event.kind === 'fort' && event.entryFee === 0,
  );
  assert.equal(freeForts.length, 50);
  for (const event of freeForts) {
    for (let replay = 1; replay <= 3; replay += 1) {
      attemptCounter += 1;
      const attemptId = `career-replay-entry:${attemptCounter}`;
      await reserveAndCommit({
        db,
        uid,
        campaignId: event.id,
        attemptId,
      });
      const eventId = `career-replay-result:${attemptCounter}`;
      const body = {
        action: 'campaign_result',
        campaignId: event.id,
        entryAttemptId: attemptId,
        placement: 1,
        totalPlayers: event.maxPlayers,
        eventId,
      };
      const replayResult = await applyEconomyEvent({ db, uid, body });
      const duplicate = await applyEconomyEvent({ db, uid, body });
      assert.equal(replayResult.accepted, true);
      assert.equal(duplicate.duplicate, true);
      assert.equal(duplicate.delta, 0);
    }
  }
});

test('the server ignores pre-server collections; a new wallet starts migrated', async () => {
  const db = new FakeFirestore({
    campaign_progress: {
      player1: {
        schemaVersion: 1,
        indiaAup: 45000,
        cleared: ['sk:india:test:1'],
      },
    },
  });

  const result = await walletForUser({ db, uid: 'player1' });

  assert.equal(result.progress.legacyMigrationVersion, 1);
  assert.equal(result.progress.registeredStarterGranted, true);
  assert.equal(totalAup(result.progress), 10000);
  assert.deepEqual(result.progress.cleared, []);
});

test('saving a wallet stores its total AUP for ranking', async () => {
  const db = new FakeFirestore();
  await walletForUser({ db, uid: 'rank-writer' });
  const stored = db.dump(SERVER_PROGRESS_COLLECTION, 'rank-writer');
  assert.equal(typeof stored.totalAup, 'number');
  const expected = ['indiaAup', 'internationalAup', 'euroAup', 'oceaniaAup', 'northAmericaAup']
    .reduce((sum, field) => sum + (stored[field] || 0), 0);
  assert.equal(stored.totalAup, expected);
});

test('global rank counts players strictly ahead, so ties share a rank', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      top: { indiaAup: 500, totalAup: 500 },
      tieA: { indiaAup: 300, totalAup: 300 },
      tieB: { euroAup: 300, totalAup: 300 },
      broke: { totalAup: 0 },
    },
  });
  assert.deepEqual(await rankForUser({ db, uid: 'top' }),
    { totalAup: 500, rank: 1, rankedPlayers: 3 });
  assert.deepEqual(await rankForUser({ db, uid: 'tieA' }),
    { totalAup: 300, rank: 2, rankedPlayers: 3 });
  assert.deepEqual(await rankForUser({ db, uid: 'tieB' }),
    { totalAup: 300, rank: 2, rankedPlayers: 3 });
});

test('players without AUP or without a wallet are unranked', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      someone: { indiaAup: 100, totalAup: 100 },
      broke: { totalAup: 0 },
    },
  });
  assert.deepEqual(await rankForUser({ db, uid: 'broke' }),
    { totalAup: 0, rank: null, rankedPlayers: 1 });
  assert.deepEqual(await rankForUser({ db, uid: 'nobody' }),
    { totalAup: 0, rank: null, rankedPlayers: 1 });
});

test('a wallet saved before totalAup existed is healed and ranked', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      leader: { indiaAup: 900, totalAup: 900 },
      legacy: { indiaAup: 400, oceaniaAup: 200 },
    },
  });
  const result = await rankForUser({ db, uid: 'legacy' });
  assert.deepEqual(result, { totalAup: 600, rank: 2, rankedPlayers: 2 });
  assert.equal(db.dump(SERVER_PROGRESS_COLLECTION, 'legacy').totalAup, 600);
});
