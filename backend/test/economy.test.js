const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { test } = require('node:test');

const {
  CLIENT_WALLET_COLLECTION,
  LEGACY_PROGRESS_COLLECTION,
  SERVER_PROGRESS_COLLECTION,
  _applyEconomyEvent,
  _baseProgress,
  _catalogVersionForRequest,
  _entryReservationStatus,
  _reserveEntry,
  _snapshotCircuitAup,
  _transitionEntryReservation,
  _walletForUser,
} = require('../src/routes/economy');
const {
  MAX_AUP_PER_CIRCUIT,
  MAX_CAMPAIGN_WIN_AUP,
} = require('../src/economy_constants');
const { FakeFirestore } = require('./firestore_fake');
const economyCatalog = require('../src/economy_catalog.json');
const {
  ECONOMY_CATALOG_494_VERSION,
  ECONOMY_CATALOG_VERSION,
  campaignEvent,
} = require('../src/economy_catalog');
const {
  ACCOUNT_DELETIONS_COLLECTION,
} = require('../src/security/firebase_auth');

function totalAup(progress) {
  return progress.indiaAup +
    progress.internationalAup +
    progress.euroAup +
    progress.oceaniaAup +
    progress.northAmericaAup;
}

function applyLegacyEconomyEvent(args) {
  return _applyEconomyEvent({
    ...args,
    allowLegacyUnsafeEvents: true,
  });
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

test('catalog negotiation keeps legacy clients compatible during rollout', () => {
  const legacy = _catalogVersionForRequest({ get: () => undefined });
  const current = _catalogVersionForRequest({
    get: () => ECONOMY_CATALOG_VERSION,
  });
  const production494 = _catalogVersionForRequest({
    get: () => ECONOMY_CATALOG_494_VERSION,
  });
  const unknown = _catalogVersionForRequest({ get: () => 'v1:999:unknown' });

  assert.equal(
    legacy,
    'v1:441:642c58b38694044f869bad6873e5c76df042c87e4abc8be3db29ebaea2e802fb',
  );
  assert.equal(current, ECONOMY_CATALOG_VERSION);
  assert.equal(production494, ECONOMY_CATALOG_494_VERSION);
  assert.equal(unknown, ECONOMY_CATALOG_VERSION);
});

test('494 reservations retain the exact event rules used before rollout', () => {
  const event494 = campaignEvent(
    'me:northAmerica:california',
    ECONOMY_CATALOG_494_VERSION,
  );
  const event550 = campaignEvent(
    'me:northAmerica:california',
    ECONOMY_CATALOG_VERSION,
  );

  assert.equal(event494.requiredFortIds.length, 6);
  assert.equal(event550.requiredFortIds.length, 10);
});

test('legacy snapshots preserve the full visible 100-Aura balance', () => {
  const progress = _baseProgress({
    indiaAup: 250000000,
    internationalAup: 250000000,
    euroAup: 250000000,
    oceaniaAup: 250000000,
  });
  const legacyProjection = _snapshotCircuitAup(
    progress,
    'v1:441:642c58b38694044f869bad6873e5c76df042c87e4abc8be3db29ebaea2e802fb',
  );
  const currentProjection = _snapshotCircuitAup(
    progress,
    ECONOMY_CATALOG_VERSION,
  );

  assert.equal(totalAup(legacyProjection), 1000000000);
  assert.equal(legacyProjection.northAmericaAup, 0);
  assert.deepEqual(currentProjection, {
    indiaAup: 200000000,
    internationalAup: 200000000,
    euroAup: 200000000,
    oceaniaAup: 200000000,
    northAmericaAup: 200000000,
  });
});

test('a deletion tombstone blocks every economy transaction from recreating state', async () => {
  const uid = 'deleted-economy-user';
  const db = new FakeFirestore({
    [ACCOUNT_DELETIONS_COLLECTION]: {
      [uid]: { schemaVersion: 1, state: 'locked' },
    },
  });
  const calls = [
    () => _walletForUser({ db, uid }),
    () => _reserveEntry({
      db,
      uid,
      body: {
        campaignId: Object.values(economyCatalog.events)[0].id,
        attemptId: 'deleted-attempt',
      },
    }),
    () => _transitionEntryReservation({
      db,
      uid,
      body: { attemptId: 'deleted-attempt' },
      transition: 'commit',
    }),
    () => _entryReservationStatus({
      db,
      uid,
      attemptId: 'deleted-attempt',
    }),
    () => _applyEconomyEvent({
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

  const result = await _applyEconomyEvent({
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
  const reserved = await _reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId },
  });
  assert.equal(reserved.accepted, true);
  const committed = await _transitionEntryReservation({
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
    const campaignId = 'sk:international:central_asia:3';
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
    const reserved = await _reserveEntry({
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

  const result = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: {
      action: 'entry_fee',
      group: 'india',
      amount: 2000,
      eventId: 'fee:india:2000:1',
    },
  });

  assert.equal(db.transactionCount, 1);
  assert.equal(result.accepted, true);
  assert.equal(result.delta, -2000);

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');
  assert.equal(saved.indiaAup, 3000);
  assert.deepEqual(saved.appliedEventIds, ['fee:india:2000:1']);
});

test('backend limits match the 200M-per-circuit client economy', () => {
  const progress = _baseProgress({
    indiaAup: MAX_AUP_PER_CIRCUIT,
    internationalAup: MAX_AUP_PER_CIRCUIT,
  });

  assert.equal(MAX_AUP_PER_CIRCUIT, 200000000);
  assert.equal(MAX_CAMPAIGN_WIN_AUP, 25000000);
  assert.equal(progress.indiaAup, 200000000);
  assert.equal(progress.internationalAup, 200000000);
});

test('legacy circuit overflow moves into North America without changing total Aura', () => {
  const progress = _baseProgress({
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
  assert.deepEqual(_baseProgress(progress), progress);
});

test('a legitimate main-event reward above 10M is credited in full', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        internationalAup: 0,
        registeredStarterGranted: true,
      },
    },
  });

  const result = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: {
      action: 'campaign_win',
      group: 'international',
      amount: 15000000,
      campaignId: 'me:international:europe',
      eventId: 'win:me:international:europe:attempt-1',
    },
  });

  assert.equal(result.accepted, true);
  assert.equal(result.delta, 15000000);
  assert.equal(result.progress.internationalAup, 15000000);
});

test('an insufficient entry fee is rejected without a deduction', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 1000,
        registeredStarterGranted: true,
      },
    },
  });

  const result = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: {
      action: 'entry_fee',
      group: 'india',
      amount: 2000,
      eventId: 'fee:india:2000:insufficient',
    },
  });

  assert.equal(result.accepted, false);
  assert.equal(result.delta, 0);
  assert.equal(result.progress.indiaAup, 1000);
});

test('invalid circuit names and zero entry fees are rejected', async () => {
  const seed = {
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        indiaAup: 5000,
        registeredStarterGranted: true,
      },
    },
  };
  const invalidGroupDb = new FakeFirestore(seed);
  const invalidGroup = await applyLegacyEconomyEvent({
    db: invalidGroupDb,
    uid: 'player1',
    body: {
      action: 'entry_fee',
      group: 'not-a-circuit',
      amount: 1000,
      eventId: 'fee:invalid:1',
    },
  });
  const zeroFeeDb = new FakeFirestore(seed);
  const zeroFee = await applyLegacyEconomyEvent({
    db: zeroFeeDb,
    uid: 'player1',
    body: {
      action: 'entry_fee',
      group: 'india',
      amount: 0,
      eventId: 'fee:india:zero',
    },
  });

  assert.equal(invalidGroup.accepted, false);
  assert.equal(invalidGroup.progress.indiaAup, 5000);
  assert.equal(zeroFee.accepted, false);
  assert.equal(zeroFee.progress.indiaAup, 5000);
});

test('duplicate event ids are idempotent', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        euroAup: 1000,
        awardedEventIds: [],
        appliedEventIds: [],
        registeredStarterGranted: true,
      },
    },
  });

  const body = {
    action: 'campaign_win',
    group: 'euro',
    amount: 3000,
    eventId: 'campaign:euro:final',
  };
  const first = await applyLegacyEconomyEvent({ db, uid: 'player1', body });
  const afterFirst = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');
  const second = await applyLegacyEconomyEvent({ db, uid: 'player1', body });
  const afterSecond = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(first.accepted, true);
  assert.equal(first.duplicate, false);
  assert.equal(first.delta, 3000);
  assert.equal(second.accepted, true);
  assert.equal(second.duplicate, true);
  assert.equal(second.delta, 0);
  assert.equal(afterFirst.euroAup, afterSecond.euroAup);
  assert.deepEqual(afterSecond.awardedEventIds, ['campaign:euro:final']);
});

test('a campaign can be replayed with a new event id and remains idempotent', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        euroAup: 0,
        awardedEventIds: [],
        appliedEventIds: [],
        registeredStarterGranted: true,
      },
    },
  });

  const firstBody = {
    action: 'campaign_win',
    group: 'euro',
    amount: 3000,
    campaignId: 'sk:euro:britain:1',
    eventId: 'win:sk:euro:britain:1:attempt-1',
  };
  const replayBody = {
    ...firstBody,
    eventId: 'win:sk:euro:britain:1:attempt-2',
  };

  const first = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: firstBody,
  });
  const replay = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: replayBody,
  });
  const duplicateReplay = await applyLegacyEconomyEvent({
    db,
    uid: 'player1',
    body: replayBody,
  });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(first.delta, 3000);
  assert.equal(replay.delta, 3000);
  assert.equal(duplicateReplay.delta, 0);
  assert.equal(saved.euroAup, 6000);
  assert.deepEqual(saved.awardedEventIds, ['sk:euro:britain:1']);
});

test('fort replay rewards have no play-count limit', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        euroAup: 0,
        awardedEventIds: [],
        appliedEventIds: [],
        registeredStarterGranted: true,
      },
    },
  });

  for (let replay = 0; replay < 550; replay += 1) {
    const result = await applyLegacyEconomyEvent({
      db,
      uid: 'player1',
      body: {
        action: 'campaign_win',
        group: 'euro',
        amount: 1,
        campaignId: 'sk:euro:britain:1',
        eventId: `win:sk:euro:britain:1:attempt-${replay + 1}`,
      },
    });

    assert.equal(result.accepted, true);
    assert.equal(result.delta, 1);
  }

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');
  assert.equal(saved.euroAup, 550);
  assert.equal(saved.appliedEventIds.length, 500);
  assert.deepEqual(saved.awardedEventIds, ['sk:euro:britain:1']);
});

test('catalog-backed entry and win ignore client fee, group, and prize claims', async () => {
  const db = new FakeFirestore();
  const uid = 'catalog-player';
  const freeFort = 'sk:international:central_asia:10';
  const attemptId = 'entry:central-asia-free:1';

  const directWin = await _applyEconomyEvent({
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

  const win = await _applyEconomyEvent({
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
  assert.equal(win.delta, 71400);

  const afterWin = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(afterWin.indiaAup, 2000);
  assert.equal(afterWin.internationalAup, 73400);
  assert.deepEqual(afterWin.cleared, [freeFort]);
  assert.equal(afterWin.entryReservations[0].status, 'settled');

  const paid = await _reserveEntry({
    db,
    uid,
    body: {
      campaignId: 'sk:international:central_asia:3',
      attemptId: 'entry:central-asia-paid:1',
      amount: 1,
      group: 'india',
    },
  });
  assert.equal(paid.accepted, true);
  assert.equal(paid.reservation.amount, 72000);
  assert.equal(paid.reservation.group, 'international');
  assert.equal(paid.delta, -72000);
  assert.equal(paid.progress.internationalAup, 1400);
});

test('secure catalog reservations allow unlimited fort replays with unique attempts', async () => {
  const db = new FakeFirestore();
  const uid = 'secure-replay-player';
  const campaignId = 'sk:international:central_asia:10';

  for (let replay = 1; replay <= 5; replay += 1) {
    const attemptId = `entry:secure-replay:${replay}`;
    await reserveAndCommit({ db, uid, campaignId, attemptId });
    const win = await _applyEconomyEvent({
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
    assert.equal(win.delta, 71400);
  }

  const saved = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  assert.equal(saved.internationalAup, 2000 + (5 * 71400));
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
        cleared: ['sk:international:central_asia:10'],
      },
    },
  });
  const campaignId = 'sk:international:central_asia:3';
  const attemptId = 'entry:recovery:1';
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const tooSoon = await _transitionEntryReservation({
    db,
    uid,
    body: { attemptId },
    transition: 'recover',
  });
  assert.equal(tooSoon.accepted, false);
  assert.equal(tooSoon.reason, 'recovery_not_ready');
  assert.equal(tooSoon.progress.internationalAup, 28000);

  const stored = db.dump(SERVER_PROGRESS_COLLECTION, uid);
  stored.entryReservations[0].updatedAtMs = 1;
  await db.collection(SERVER_PROGRESS_COLLECTION).doc(uid).set(stored);

  const recovered = await _transitionEntryReservation({
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

  const duplicate = await _transitionEntryReservation({
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
  const campaignId = 'sk:international:central_asia:10';
  const firstAttempt = 'entry:single-active:1';

  const first = await _reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: firstAttempt },
  });
  assert.equal(first.accepted, true);

  const conflict = await _reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:2' },
  });
  assert.equal(conflict.accepted, false);
  assert.equal(conflict.reason, 'active_entry_conflict');
  assert.equal(conflict.reservation.attemptId, firstAttempt);

  await _transitionEntryReservation({
    db,
    uid,
    body: { attemptId: firstAttempt },
    transition: 'commit',
  });
  const committedConflict = await _reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:3' },
  });
  assert.equal(committedConflict.accepted, false);
  assert.equal(committedConflict.reservation.status, 'committed');

  await _applyEconomyEvent({
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
  const afterSettlement = await _reserveEntry({
    db,
    uid,
    body: { campaignId, attemptId: 'entry:single-active:4' },
  });
  assert.equal(afterSettlement.accepted, true);
});

test('campaign result settles unpaid ranks, records stats once, and never refunds a loss', async () => {
  const db = new FakeFirestore();
  const uid = 'loss-player';
  const campaignId = 'sk:international:central_asia:10';
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
  const result = await _applyEconomyEvent({ db, uid, body });
  const duplicate = await _applyEconomyEvent({ db, uid, body });

  assert.equal(result.accepted, true);
  assert.equal(result.payoutDelta, 0);
  assert.equal(result.clearRecorded, false);
  assert.equal(result.matchRecorded, true);
  assert.equal(result.progress.matchesPlayed, 1);
  assert.equal(result.progress.entryReservations[0].status, 'settled');
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.progress.matchesPlayed, 1);

  const recovery = await _transitionEntryReservation({
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
  const campaignId = 'sk:international:central_asia:10';
  const attemptId = 'entry:table-size-forgery:1';
  const authoritativePlayers = economyCatalog.events[campaignId].maxPlayers;
  assert.equal(authoritativePlayers, 6);
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const forged = await _applyEconomyEvent({
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

  const valid = await _applyEconomyEvent({
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
  const campaignId = 'sk:international:central_asia:10';
  const attemptId = 'entry:abandon-placement-forgery:1';
  const totalPlayers = economyCatalog.events[campaignId].maxPlayers;
  await reserveAndCommit({ db, uid, campaignId, attemptId });

  const forged = await _applyEconomyEvent({
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

  const valid = await _applyEconomyEvent({
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
        const grindResult = await _applyEconomyEvent({
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
      const result = await _applyEconomyEvent({
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
    const title = await _applyEconomyEvent({
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
      const replayResult = await _applyEconomyEvent({ db, uid, body });
      const duplicate = await _applyEconomyEvent({ db, uid, body });
      assert.equal(replayResult.accepted, true);
      assert.equal(duplicate.duplicate, true);
      assert.equal(duplicate.delta, 0);
    }
  }
});

test('wallet hydrates from legacy progress and grants starter AUP once', async () => {
  const db = new FakeFirestore({
    [LEGACY_PROGRESS_COLLECTION]: {
      player1: {
        schemaVersion: 1,
        awardedEventIds: ['legacy:event'],
      },
    },
  });

  const result = await _walletForUser({
    db,
    uid: 'player1',
    allowLegacyMigration: true,
  });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(result.exists, true);
  assert.equal(result.migrated, true);
  assert.equal(result.progress.registeredStarterGranted, true);
  assert.equal(totalAup(result.progress), 10000);
  assert.equal(saved.migratedFrom, LEGACY_PROGRESS_COLLECTION);
  assert.deepEqual(saved.awardedEventIds, ['legacy:event']);
});

test('wallet migration prefers the dedicated version-2 client wallet', async () => {
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

  const result = await _walletForUser({
    db,
    uid: 'player1',
    allowLegacyMigration: true,
  });
  const saved = db.dump(SERVER_PROGRESS_COLLECTION, 'player1');

  assert.equal(result.migrated, true);
  assert.equal(result.progress.indiaAup, 45000);
  assert.equal(
    saved.migratedFrom,
    `${LEGACY_PROGRESS_COLLECTION}+${CLIENT_WALLET_COLLECTION}`,
  );
  assert.deepEqual(saved.cleared, []);
});
