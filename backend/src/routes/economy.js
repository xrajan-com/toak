const express = require('express');
const rateLimit = require('express-rate-limit');
const crypto = require('node:crypto');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const {
  assertAccountActiveInTransaction,
  firebaseAdminApp,
  isAccountDeletedError,
  requireRegisteredFirebaseAuth,
} = require('../security/firebase_auth');
const {
  LEGACY_MAX_AUP_PER_CIRCUIT,
  MAX_AUP_PER_CIRCUIT,
  MAX_TOTAL_AUP,
  MAX_CAMPAIGN_WIN_AUP,
  MAX_ENTRY_FEE,
  normalizeCircuitAup,
} = require('../economy_constants');
const {
  ECONOMY_CATALOG_494_VERSION,
  ECONOMY_CATALOG_VERSION,
  LEGACY_ECONOMY_CATALOG_VERSION,
  campaignEvent,
  requestedCatalogVersion,
} = require('../economy_catalog');
const {
  LEGACY_MIGRATION_VERSION,
  mergeLegacyEconomy,
} = require('../legacy_economy_migration');

const SERVER_PROGRESS_COLLECTION = 'server_progress';
const LEGACY_PROGRESS_COLLECTION = 'campaign_progress';
const CLIENT_WALLET_COLLECTION = 'aura_wallets';
const ECONOMY_RECEIPTS_COLLECTION = 'economy_receipts';

const REGISTERED_STARTER_AUP = 10000;
const CIRCUIT_FIELDS = [
  'northAmericaAup',
  'oceaniaAup',
  'euroAup',
  'indiaAup',
  'internationalAup',
];

const QUIT_PENALTY_PERMILLE = 3;
const LOSS_PENALTY_PERMILLE = 1;
const MAX_STORED_ENTRY_RESERVATIONS = 40;
const ENTRY_RESERVATION_TTL_MS = 60 * 60 * 1000;
const ENTRY_RECOVERY_DELAY_MS = 10 * 60 * 1000;

function _envFlag(name) {
  return /^(1|true|yes)$/i.test((process.env[name] || '').trim());
}

function _legacyMigrationEnabled() {
  return _envFlag('ALLOW_LEGACY_CLIENT_ECONOMY_MIGRATION');
}

function _legacyUnsafeEventsEnabled() {
  return _envFlag('ALLOW_LEGACY_UNCATALOGUED_ECONOMY_EVENTS');
}

function _asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch((error) => {
    if (isAccountDeletedError(error)) {
      return res.status(410).json({
        code: 'account_deleted',
        error: 'This account has been deleted.',
        requestId: req.requestId,
      });
    }
    return next(error);
  });
}

function _db() {
  return getFirestore(firebaseAdminApp());
}

async function _refreshLeaderboard({
  db,
  uid,
  refreshLeaderboard,
  requestId,
}) {
  if (typeof refreshLeaderboard !== 'function') return null;
  try {
    return await refreshLeaderboard({ db, uid });
  } catch (error) {
    // Economy writes are authoritative and must not be rolled back because a
    // derived public projection failed. Log the failure so the next
    // Aura-changing request can repair the leaderboard row automatically.
    console.error(JSON.stringify({
      severity: 'ERROR',
      event: 'leaderboard_refresh_failed',
      requestId,
      errorName: error?.name || 'Error',
      errorCode: error?.code || 'internal',
    }));
    return null;
  }
}

function _clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function _int(value, { fallback = 0, min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return _clamp(Math.trunc(value), min, max);
}

function _group(raw) {
  if (raw === 'india') return 'india';
  if (raw === 'international') return 'international';
  if (raw === 'euro') return 'euro';
  if (
    raw === 'northAmerica' ||
    raw === 'north_america' ||
    raw === 'north-america'
  ) {
    return 'northAmerica';
  }
  if (raw === 'oceania' || raw === '7seas' || raw === 'seven_seas') {
    return 'oceania';
  }
  return null;
}

function _fieldForGroup(group) {
  switch (group) {
    case 'international':
      return 'internationalAup';
    case 'euro':
      return 'euroAup';
    case 'oceania':
      return 'oceaniaAup';
    case 'northAmerica':
      return 'northAmericaAup';
    default:
      return 'indiaAup';
  }
}

function _totalAup(progress) {
  return CIRCUIT_FIELDS.reduce((sum, field) => sum + _int(progress[field]), 0);
}

function _dayKeyUtc(ms = Date.now()) {
  return new Date(ms).toISOString().slice(0, 10);
}

function _eventId(raw) {
  if (typeof raw !== 'string') return '';
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length > 120) return '';
  return trimmed;
}

function _receiptId(uid, eventId) {
  const digest = crypto
    .createHash('sha256')
    .update(`${uid}\u0000${eventId}`)
    .digest('hex');
  return `${uid.slice(0, 40)}_${digest}`;
}

function _stringList(raw, max) {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((value) => typeof value === 'string' && value.length <= 120)
    .slice(-max);
}

function _reservation(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const attemptId = _eventId(raw.attemptId);
  const campaignId = _eventId(raw.campaignId);
  const group = _group(raw.group);
  const amount = _int(raw.amount, { min: 0, max: MAX_ENTRY_FEE });
  const status = ['reserved', 'committed', 'refunded', 'settled'].includes(raw.status)
    ? raw.status
    : '';
  if (!attemptId || !campaignId || !group || !status) return null;
  return {
    attemptId,
    campaignId,
    group,
    amount,
    status,
    // Reservations created by the immediately preceding production backend
    // predate this field and necessarily used the 494-event catalog.
    catalogVersion: typeof raw.catalogVersion === 'string'
      ? requestedCatalogVersion(raw.catalogVersion)
      : ECONOMY_CATALOG_494_VERSION,
    createdAtMs: _int(raw.createdAtMs, { min: 0, max: 9999999999999 }),
    updatedAtMs: _int(raw.updatedAtMs, { min: 0, max: 9999999999999 }),
  };
}

function _finishPermille({ finishRank, totalPlayers }) {
  if (totalPlayers <= 1) return 0;
  const r = _clamp(finishRank, 1, totalPlayers);
  const denom = Math.max(totalPlayers - 1, 1);
  return _clamp(Math.trunc(((r - 1) * 1000) / denom), 0, 1000);
}

function _baseProgress(data = {}) {
  const circuitAup = normalizeCircuitAup(data);
  return {
    schemaVersion: 1,
    walletVersion: _int(data.walletVersion, {
      min: 0,
      max: Number.MAX_SAFE_INTEGER,
    }),
    ...circuitAup,
    awardedEventIds: _stringList(data.awardedEventIds, 500),
    cleared: _stringList(data.cleared, 500),
    mainEventsCleared: _stringList(data.mainEventsCleared, 200),
    registeredStarterGranted: data.registeredStarterGranted === true,
    legacyMigrationVersion: _int(data.legacyMigrationVersion, {
      min: 0,
      max: LEGACY_MIGRATION_VERSION,
    }),
    legacyMigrationSources: _stringList(data.legacyMigrationSources, 4),
    appliedEventIds: Array.isArray(data.appliedEventIds)
      ? data.appliedEventIds.filter((v) => typeof v === 'string').slice(-500)
      : [],
    lastActiveAtMs: _int(data.lastActiveAtMs, { min: 0, max: 9999999999999 }),
    prevActiveAtMs: _int(data.prevActiveAtMs, { min: 0, max: 9999999999999 }),
    lastActiveDayKey: typeof data.lastActiveDayKey === 'string'
      ? data.lastActiveDayKey.slice(0, 16)
      : '',
    activityScore: _int(data.activityScore, { min: 0, max: 10000 }),
    abandonedGames: _int(data.abandonedGames, { min: 0, max: 2000000000 }),
    matchesPlayed: _int(data.matchesPlayed, { min: 0, max: 2000000000 }),
    finishPermilleSum: _int(data.finishPermilleSum, {
      min: 0,
      max: 2000000000,
    }),
    rewardedAdDayKey: typeof data.rewardedAdDayKey === 'string'
      ? data.rewardedAdDayKey.slice(0, 16)
      : '',
    rewardedAdDayCount: _int(data.rewardedAdDayCount, { min: 0, max: 100000 }),
    entryReservations: Array.isArray(data.entryReservations)
      ? data.entryReservations
        .map(_reservation)
        .filter(Boolean)
        .slice(-MAX_STORED_ENTRY_RESERVATIONS)
      : [],
  };
}

function _catalogVersionForRequest(req) {
  return requestedCatalogVersion(req.get('x-economy-catalog-version'));
}

function _snapshotCircuitAup(progress, catalogVersion) {
  const current = {
    indiaAup: progress.indiaAup,
    internationalAup: progress.internationalAup,
    euroAup: progress.euroAup,
    oceaniaAup: progress.oceaniaAup,
    northAmericaAup: progress.northAmericaAup,
  };
  if (catalogVersion !== LEGACY_ECONOMY_CATALOG_VERSION) return current;

  // Legacy clients only sum four circuit fields. Project North America into
  // the old 25-Aura headroom, preferring circuits already at the new cap. This
  // preserves their visible total without changing authoritative storage.
  let remaining = current.northAmericaAup;
  const legacyFields = [
    'indiaAup',
    'internationalAup',
    'euroAup',
    'oceaniaAup',
  ].sort((a, b) => current[b] - current[a]);
  for (const field of legacyFields) {
    const headroom = LEGACY_MAX_AUP_PER_CIRCUIT - current[field];
    const projected = Math.min(Math.max(headroom, 0), remaining);
    current[field] += projected;
    remaining -= projected;
  }
  current.northAmericaAup = 0;
  return current;
}

function _snapshot(progress, catalogVersion = ECONOMY_CATALOG_VERSION) {
  const circuitAup = _snapshotCircuitAup(progress, catalogVersion);
  return {
    schemaVersion: 1,
    walletVersion: progress.walletVersion,
    ...circuitAup,
    awardedEventIds: progress.awardedEventIds,
    cleared: progress.cleared,
    mainEventsCleared: progress.mainEventsCleared,
    registeredStarterGranted: progress.registeredStarterGranted,
    legacyMigrationVersion: progress.legacyMigrationVersion,
    lastActiveAtMs: progress.lastActiveAtMs,
    prevActiveAtMs: progress.prevActiveAtMs,
    lastActiveDayKey: progress.lastActiveDayKey,
    activityScore: progress.activityScore,
    abandonedGames: progress.abandonedGames,
    matchesPlayed: progress.matchesPlayed,
    finishPermilleSum: progress.finishPermilleSum,
    catalogVersion,
  };
}

async function _loadProgressInTransaction({
  tx,
  serverRef,
  legacyRef,
  clientWalletRef,
  allowLegacyMigration,
}) {
  const serverSnap = await tx.get(serverRef);
  const serverData = serverSnap.exists ? (serverSnap.data() || {}) : {};
  if (
    serverSnap.exists &&
    (!allowLegacyMigration ||
      _int(serverData.legacyMigrationVersion) >= LEGACY_MIGRATION_VERSION)
  ) {
    const data = serverData;
    const progress = _baseProgress(data);
    return {
      existed: true,
      migratedFrom: null,
      legacyMerged: false,
      normalizedCircuitAup: CIRCUIT_FIELDS.some(
        (field) => _int(data[field]) !== progress[field],
      ),
      progress,
    };
  }

  if (allowLegacyMigration) {
    const campaignSnap = await tx.get(legacyRef);
    const walletSnap = await tx.get(clientWalletRef);
    const merged = mergeLegacyEconomy({
      serverData,
      campaignData: campaignSnap.exists ? campaignSnap.data() : null,
      walletData: walletSnap.exists ? walletSnap.data() : null,
    });
    if (merged.walletConflict) {
      const error = new Error('Legacy wallet conflicts with server progress.');
      error.code = 'legacy_wallet_conflict';
      throw error;
    }
    const progress = _baseProgress(merged.data);
    return {
      existed: serverSnap.exists,
      migratedFrom: merged.sources.join('+') || null,
      legacyMerged: true,
      normalizedCircuitAup: CIRCUIT_FIELDS.some(
        (field) => _int(merged.data[field]) !== progress[field],
      ),
      progress,
    };
  }

  // A document created after the migration cutover has no legacy state to
  // merge. Mark it complete so current clients can fail closed on old rows.
  return {
    existed: false,
    migratedFrom: null,
    legacyMerged: false,
    normalizedCircuitAup: false,
    progress: _baseProgress({
      legacyMigrationVersion: LEGACY_MIGRATION_VERSION,
      legacyMigrationSources: [],
    }),
  };
}

function _saveProgress(tx, ref, progress, { migratedFrom } = {}) {
  progress.walletVersion = _clamp(
    progress.walletVersion + 1,
    0,
    Number.MAX_SAFE_INTEGER,
  );
  tx.set(
    ref,
    {
      ...progress,
      ...(migratedFrom ? { migratedFrom } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function _findReservation(progress, attemptId) {
  return progress.entryReservations.find(
    (reservation) => reservation.attemptId === attemptId,
  );
}

function _putReservation(progress, reservation) {
  const withoutAttempt = progress.entryReservations.filter(
    (candidate) => candidate.attemptId !== reservation.attemptId,
  );
  const all = [...withoutAttempt, reservation];
  const active = all.filter(
    (candidate) =>
      candidate.status === 'reserved' || candidate.status === 'committed',
  );
  const terminal = all.filter(
    (candidate) =>
      candidate.status !== 'reserved' && candidate.status !== 'committed',
  );
  const terminalSlots = Math.max(
    0,
    MAX_STORED_ENTRY_RESERVATIONS - active.length,
  );
  // Active attempts are never evicted by bounded history pruning.
  progress.entryReservations = [
    ...(terminalSlots > 0 ? terminal.slice(-terminalSlots) : []),
    ...active,
  ];
}

function _reconcileExpiredReservations(progress, nowMs = Date.now()) {
  let refunded = 0;
  for (const reservation of progress.entryReservations) {
    if (
      reservation.status !== 'reserved' ||
      reservation.createdAtMs <= 0 ||
      nowMs - reservation.createdAtMs < ENTRY_RESERVATION_TTL_MS
    ) {
      continue;
    }
    refunded += _addAup(progress, reservation.group, reservation.amount);
    reservation.status = 'refunded';
    reservation.updatedAtMs = nowMs;
  }
  return refunded;
}

function _entryPrerequisitesMet(progress, event) {
  if (event.kind === 'fort') {
    // Forts may be entered in any order. The authoritative reservation path
    // still enforces the catalog fee against the user's circuit wallet.
    return true;
  }
  if (event.kind === 'main') {
    return Array.isArray(event.requiredFortIds) &&
      event.requiredFortIds.every((id) => progress.cleared.includes(id));
  }
  return false;
}

function _recordCampaignClear(progress, event) {
  if (event.kind === 'main') {
    if (!progress.mainEventsCleared.includes(event.id)) {
      progress.mainEventsCleared.push(event.id);
      progress.mainEventsCleared = progress.mainEventsCleared.slice(-200);
    }
    return;
  }
  if (!progress.cleared.includes(event.id)) {
    progress.cleared.push(event.id);
    progress.cleared = progress.cleared.slice(-500);
  }
}

function _touchActivity(progress) {
  const nowMs = Date.now();
  if (progress.lastActiveAtMs > 0 && nowMs > progress.lastActiveAtMs) {
    progress.prevActiveAtMs = progress.lastActiveAtMs;
  }
  progress.lastActiveAtMs = nowMs;

  const today = _dayKeyUtc(nowMs);
  if (progress.lastActiveDayKey !== today) {
    progress.activityScore = _clamp(progress.activityScore + 1, 0, 10000);
    progress.lastActiveDayKey = today;
  }
}

function _addAup(progress, group, amount) {
  const field = _fieldForGroup(group);
  const before = progress[field];
  progress[field] = _clamp(progress[field] + amount, 0, MAX_AUP_PER_CIRCUIT);
  return progress[field] - before;
}

function _grantRegisteredStarterAup(progress) {
  if (progress.registeredStarterGranted) return progress;
  const total = _totalAup(progress);
  if (total <= 0) {
    let remaining = REGISTERED_STARTER_AUP;
    CIRCUIT_FIELDS.forEach((field, index) => {
      const grant = index === CIRCUIT_FIELDS.length - 1
        ? remaining
        : Math.trunc(REGISTERED_STARTER_AUP / CIRCUIT_FIELDS.length);
      progress[field] = _clamp(progress[field] + grant, 0, MAX_AUP_PER_CIRCUIT);
      remaining -= grant;
    });
  }
  progress.registeredStarterGranted = true;
  return progress;
}

function _deductAup(progress, group, amount) {
  if (amount <= 0) return 0;
  const field = _fieldForGroup(group);
  if (progress[field] < amount) return -1;
  progress[field] = _clamp(progress[field] - amount, 0, MAX_AUP_PER_CIRCUIT);
  return amount;
}

function _deductAupTotal(progress, amount) {
  let remaining = _int(amount, { min: 0, max: MAX_TOTAL_AUP });
  if (remaining <= 0) return 0;
  const before = _totalAup(progress);
  for (const field of CIRCUIT_FIELDS) {
    const take = Math.min(progress[field], remaining);
    progress[field] -= take;
    remaining -= take;
    if (remaining <= 0) break;
  }
  return before - _totalAup(progress);
}

function _deductPermille(progress, permille) {
  const total = _totalAup(progress);
  const amount = Math.trunc((total * permille) / 1000);
  return _deductAupTotal(progress, amount);
}

async function _applyEconomyEvent({
  db,
  uid,
  body,
  catalogVersion = ECONOMY_CATALOG_VERSION,
  allowLegacyMigration = _legacyMigrationEnabled(),
  allowLegacyUnsafeEvents = _legacyUnsafeEventsEnabled(),
}) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgressInTransaction({
      tx,
      serverRef: ref,
      legacyRef,
      clientWalletRef,
      allowLegacyMigration,
    });
    const progress = loaded.progress;
    const auraTotalBefore = _totalAup(progress);
    _grantRegisteredStarterAup(progress);
    const action = typeof body.action === 'string' ? body.action : '';
    const eventId = _eventId(body.eventId);
    if (!eventId) {
      return {
        accepted: false,
        duplicate: false,
        delta: 0,
        reason: 'event_id_required',
        progress,
      };
    }

    const receiptRef = db
      .collection(ECONOMY_RECEIPTS_COLLECTION)
      .doc(_receiptId(uid, eventId));
    const receiptSnap = await tx.get(receiptRef);
    if (receiptSnap.exists) {
      const receipt = receiptSnap.data() || {};
      return {
        accepted: receipt.accepted === true,
        duplicate: true,
        delta: 0,
        payoutDelta: 0,
        penaltyDelta: 0,
        clearRecorded: receipt.clearRecorded === true,
        matchRecorded: receipt.matchRecorded === true,
        reason: receipt.reason || 'duplicate',
        progress,
      };
    }

    _reconcileExpiredReservations(progress);
    let accepted = false;
    let delta = 0;
    let payoutDelta = 0;
    let penaltyDelta = 0;
    let clearRecorded = false;
    let matchRecorded = false;
    let reason = 'unsupported_action';
    let campaignId = '';

    if (action === 'rewarded_ad') {
      // Never trust a client assertion that an ad was watched. Rewarded ads are
      // disabled in the current release, and credits must remain disabled until
      // a server-verified ad-provider callback/SSV flow is implemented.
      reason = 'rewarded_ad_verification_required';
    } else if (action === 'entry_fee') {
      if (!allowLegacyUnsafeEvents) {
        return {
          accepted: false,
          duplicate: false,
          delta: 0,
          reason: 'entry_reservation_required',
          progress,
        };
      }
      const group = _group(body.group);
      const amount = _int(body.amount, { min: 0, max: MAX_ENTRY_FEE });
      if (group && amount > 0) {
        const paid = _deductAup(progress, group, amount);
        accepted = paid >= 0;
        delta = paid >= 0 ? -paid : 0;
        reason = accepted ? 'accepted' : 'insufficient_funds';
      } else {
        reason = group ? 'invalid_amount' : 'invalid_group';
      }
    } else if (
      action === 'campaign_win' ||
      action === 'campaign_result' ||
      action === 'campaign_abandoned'
    ) {
      const isAbandoned = action === 'campaign_abandoned';
      const isFinalResult = action === 'campaign_result' || isAbandoned;
      campaignId = _eventId(body.campaignId);
      const attemptId = _eventId(body.entryAttemptId);
      const reservation = attemptId
        ? _findReservation(progress, attemptId)
        : null;
      const settlementCatalogVersion = reservation?.catalogVersion ||
        catalogVersion;
      const event = campaignEvent(campaignId, settlementCatalogVersion);
      const totalPlayers = event?.maxPlayers ?? 0;
      const totalPlayersValid = body.totalPlayers == null ||
        (Number.isInteger(body.totalPlayers) &&
          body.totalPlayers === totalPlayers);
      const placement = isAbandoned
        ? totalPlayers
        : _int(body.placement, { min: 1, max: totalPlayers });
      const placementValid = isAbandoned
        ? body.placement == null || body.placement === totalPlayers
        : Number.isInteger(body.placement) &&
          body.placement >= 1 &&
          body.placement <= totalPlayers;
      const payout = !isAbandoned && event && Array.isArray(event.payouts)
        ? _int(event.payouts[placement - 1], {
          min: 0,
          max: MAX_CAMPAIGN_WIN_AUP,
        })
        : 0;
      if (
        action === 'campaign_win' &&
        allowLegacyUnsafeEvents &&
        body.amount != null &&
        !_eventId(body.entryAttemptId)
      ) {
        if (!campaignId) campaignId = eventId;
        const legacyGroup = _group(body.group);
        const legacyAmount = _int(body.amount, {
          min: 0,
          max: MAX_CAMPAIGN_WIN_AUP,
        });
        if (legacyGroup && legacyAmount > 0) {
          delta = _addAup(progress, legacyGroup, legacyAmount);
          accepted = true;
          reason = delta > 0 ? 'accepted' : 'wallet_cap_reached';
          if (campaignId && !progress.awardedEventIds.includes(campaignId)) {
            progress.awardedEventIds.push(campaignId);
            progress.awardedEventIds = progress.awardedEventIds.slice(-500);
          }
        } else {
          reason = legacyGroup ? 'invalid_amount' : 'invalid_group';
        }
      } else if (!event) {
        reason = 'invalid_campaign_event';
      } else if (!totalPlayersValid) {
        reason = 'invalid_total_players';
      } else if (!placementValid) {
        reason = 'invalid_placement';
      } else if (!isFinalResult && payout <= 0) {
        reason = 'invalid_placement';
      } else {
        const reservationValid = reservation != null &&
          reservation.campaignId === event.id &&
          reservation.group === event.group;
        if (!reservationValid && !allowLegacyUnsafeEvents) {
          reason = 'committed_entry_required';
        } else if (
          reservationValid &&
          !['committed', 'settled'].includes(reservation.status)
        ) {
          reason = 'entry_not_committed';
        } else if (reservation?.status === 'settled') {
          accepted = true;
          reason = 'duplicate_settlement';
          clearRecorded = !isAbandoned && placement === 1 &&
            (event.kind === 'main'
              ? progress.mainEventsCleared.includes(event.id)
              : progress.cleared.includes(event.id));
        } else {
          if (isFinalResult) {
            progress.matchesPlayed = _clamp(
              progress.matchesPlayed + 1,
              0,
              2000000000,
            );
            progress.finishPermilleSum = _clamp(
              progress.finishPermilleSum +
                _finishPermille({ finishRank: placement, totalPlayers }),
              0,
              2000000000,
            );
            matchRecorded = true;
            if (isAbandoned) {
              progress.abandonedGames = _clamp(
                progress.abandonedGames + 1,
                0,
                2000000000,
              );
              penaltyDelta = -_deductPermille(
                progress,
                QUIT_PENALTY_PERMILLE,
              );
            } else if (placement !== 1) {
              penaltyDelta = -_deductPermille(
                progress,
                LOSS_PENALTY_PERMILLE,
              );
            }
          }
          payoutDelta = _addAup(progress, event.group, payout);
          delta = payoutDelta + penaltyDelta;
          accepted = true;
          reason = payout > 0 && payoutDelta === 0
            ? 'wallet_cap_reached'
            : 'accepted';
          if (!isAbandoned && placement === 1) {
            _recordCampaignClear(progress, event);
            clearRecorded = true;
          }
          if (!isAbandoned && !progress.awardedEventIds.includes(campaignId)) {
            progress.awardedEventIds.push(campaignId);
            progress.awardedEventIds = progress.awardedEventIds.slice(-500);
          }
          if (reservationValid) {
            reservation.status = 'settled';
            reservation.updatedAtMs = Date.now();
          }
        }
      }
    } else if (action === 'match_completed') {
      const heroWon = body.heroWon === true;
      const totalPlayers = _int(body.totalPlayers, { min: 1, max: 10 });
      const finishRank = _int(body.finishRank, { min: 1, max: totalPlayers });
      progress.matchesPlayed = _clamp(progress.matchesPlayed + 1, 0, 2000000000);
      progress.finishPermilleSum = _clamp(
        progress.finishPermilleSum + _finishPermille({ finishRank, totalPlayers }),
        0,
        2000000000,
      );
      delta = heroWon ? 0 : -_deductPermille(progress, LOSS_PENALTY_PERMILLE);
      const reservation = _findReservation(
        progress,
        _eventId(body.entryAttemptId),
      );
      if (
        reservation &&
        (reservation.status === 'committed' ||
          reservation.status === 'reserved')
      ) {
        reservation.status = 'settled';
        reservation.updatedAtMs = Date.now();
      }
      accepted = true;
      reason = 'accepted';
    } else if (action === 'game_abandoned') {
      const totalPlayers = _int(body.totalPlayers, { min: 1, max: 10 });
      progress.abandonedGames = _clamp(progress.abandonedGames + 1, 0, 2000000000);
      progress.matchesPlayed = _clamp(progress.matchesPlayed + 1, 0, 2000000000);
      progress.finishPermilleSum = _clamp(
        progress.finishPermilleSum +
          _finishPermille({ finishRank: totalPlayers, totalPlayers }),
        0,
        2000000000,
      );
      delta = -_deductPermille(progress, QUIT_PENALTY_PERMILLE);
      const reservation = _findReservation(
        progress,
        _eventId(body.entryAttemptId),
      );
      if (
        reservation &&
        (reservation.status === 'committed' ||
          reservation.status === 'reserved')
      ) {
        reservation.status = 'settled';
        reservation.updatedAtMs = Date.now();
      }
      accepted = true;
      reason = 'accepted';
    }

    if (!accepted) {
      return {
        accepted: false,
        duplicate: false,
        delta: 0,
        reason,
        progress,
      };
    }

    progress.appliedEventIds.push(eventId);
    progress.appliedEventIds = progress.appliedEventIds.slice(-500);
    _touchActivity(progress);
    _saveProgress(tx, ref, progress, { migratedFrom: loaded.migratedFrom });
    tx.set(receiptRef, {
      uid,
      eventId,
      action,
      campaignId,
      accepted: true,
      reason,
      delta,
      payoutDelta,
      penaltyDelta,
      clearRecorded,
      matchRecorded,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      accepted,
      duplicate: false,
      auraChanged: _totalAup(progress) !== auraTotalBefore,
      delta,
      payoutDelta,
      penaltyDelta,
      clearRecorded,
      matchRecorded,
      reason,
      progress,
    };
  });
}

async function _reserveEntry({
  db,
  uid,
  body,
  catalogVersion = ECONOMY_CATALOG_VERSION,
  allowLegacyMigration = _legacyMigrationEnabled(),
}) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgressInTransaction({
      tx,
      serverRef: ref,
      legacyRef,
      clientWalletRef,
      allowLegacyMigration,
    });
    const progress = loaded.progress;
    const auraTotalBefore = _totalAup(progress);
    _grantRegisteredStarterAup(progress);
    const expiredRefund = _reconcileExpiredReservations(progress);

    const attemptId = _eventId(body.attemptId);
    const campaignId = _eventId(body.campaignId);
    const event = campaignEvent(campaignId, catalogVersion);
    if (!attemptId) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: 'attempt_id_required',
        progress,
      };
    }
    if (!event) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: 'invalid_campaign_event',
        progress,
      };
    }

    const existing = _findReservation(progress, attemptId);
    if (existing) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      if (existing.campaignId !== campaignId) {
        return {
          accepted: false,
          duplicate: false,
          auraChanged: _totalAup(progress) !== auraTotalBefore,
          reason: 'attempt_id_conflict',
          reservation: existing,
          progress,
        };
      }
      const accepted = ['reserved', 'committed', 'settled'].includes(
        existing.status,
      );
      return {
        accepted,
        duplicate: true,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: accepted ? 'accepted' : 'reservation_refunded',
        reservation: existing,
        progress,
      };
    }

    const activeReservation = progress.entryReservations.find(
      (candidate) =>
        candidate.status === 'reserved' ||
        candidate.status === 'committed',
    );
    if (activeReservation) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: 'active_entry_conflict',
        reservation: activeReservation,
        progress,
      };
    }

    if (!_entryPrerequisitesMet(progress, event)) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: 'campaign_locked',
        progress,
      };
    }

    const amount = _int(event.entryFee, { min: 0, max: MAX_ENTRY_FEE });
    const paid = amount <= 0 ? 0 : _deductAup(progress, event.group, amount);
    if (paid < 0) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        auraChanged: _totalAup(progress) !== auraTotalBefore,
        reason: 'insufficient_funds',
        progress,
      };
    }

    const nowMs = Date.now();
    const reservation = {
      attemptId,
      campaignId,
      group: event.group,
      amount,
      status: 'reserved',
      catalogVersion,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    };
    _putReservation(progress, reservation);
    _touchActivity(progress);
    _saveProgress(tx, ref, progress, { migratedFrom: loaded.migratedFrom });
    return {
      accepted: true,
      duplicate: false,
      auraChanged: _totalAup(progress) !== auraTotalBefore,
      reason: amount <= 0 ? 'free_entry_reserved' : 'accepted',
      delta: -amount + expiredRefund,
      reservation,
      progress,
    };
  });
}

async function _transitionEntryReservation({
  db,
  uid,
  body,
  transition,
  allowLegacyMigration = _legacyMigrationEnabled(),
}) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgressInTransaction({
      tx,
      serverRef: ref,
      legacyRef,
      clientWalletRef,
      allowLegacyMigration,
    });
    const progress = loaded.progress;
    const auraTotalBefore = _totalAup(progress);
    _grantRegisteredStarterAup(progress);
    const expiredRefund = _reconcileExpiredReservations(progress);
    const attemptId = _eventId(body.attemptId);
    const reservation = attemptId
      ? _findReservation(progress, attemptId)
      : null;
    if (!attemptId) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        reason: 'attempt_id_required',
        progress,
      };
    }
    if (!reservation) {
      if (loaded.legacyMerged || expiredRefund > 0) {
        _saveProgress(tx, ref, progress, {
          migratedFrom: loaded.migratedFrom,
        });
      }
      return {
        accepted: false,
        duplicate: false,
        reason: 'reservation_not_found',
        progress,
      };
    }

    let accepted = false;
    let duplicate = false;
    let reason = 'invalid_reservation_state';
    let delta = expiredRefund;
    if (transition === 'commit') {
      if (reservation.status === 'reserved') {
        reservation.status = 'committed';
        reservation.updatedAtMs = Date.now();
        accepted = true;
        reason = 'accepted';
      } else if (
        reservation.status === 'committed' ||
        reservation.status === 'settled'
      ) {
        accepted = true;
        duplicate = true;
        reason = 'accepted';
      } else {
        reason = 'reservation_refunded';
      }
    } else if (transition === 'refund') {
      if (reservation.status === 'reserved') {
        delta += _addAup(
          progress,
          reservation.group,
          reservation.amount,
        );
        reservation.status = 'refunded';
        reservation.updatedAtMs = Date.now();
        accepted = true;
        reason = 'accepted';
      } else if (reservation.status === 'refunded') {
        accepted = true;
        duplicate = true;
        reason = 'accepted';
      } else {
        reason = reservation.status === 'settled'
          ? 'entry_already_settled'
          : 'entry_already_committed';
      }
    } else if (transition === 'recover') {
      if (reservation.status === 'committed') {
        const ageMs = Date.now() - reservation.updatedAtMs;
        if (ageMs < ENTRY_RECOVERY_DELAY_MS) {
          reason = 'recovery_not_ready';
        } else {
          const refunded = _addAup(
            progress,
            reservation.group,
            reservation.amount,
          );
          const penalty = _deductPermille(
            progress,
            QUIT_PENALTY_PERMILLE,
          );
          delta += refunded - penalty;
          reservation.status = 'refunded';
          reservation.updatedAtMs = Date.now();
          progress.abandonedGames = _clamp(
            progress.abandonedGames + 1,
            0,
            2000000000,
          );
          progress.matchesPlayed = _clamp(
            progress.matchesPlayed + 1,
            0,
            2000000000,
          );
          accepted = true;
          reason = 'abandoned_entry_recovered';
        }
      } else if (reservation.status === 'refunded') {
        accepted = true;
        duplicate = true;
        reason = 'abandoned_entry_recovered';
      } else {
        reason = reservation.status === 'settled'
          ? 'entry_already_settled'
          : 'entry_not_committed';
      }
    }

    if (accepted || loaded.legacyMerged || expiredRefund > 0) {
      _saveProgress(tx, ref, progress, { migratedFrom: loaded.migratedFrom });
    }
    return {
      accepted,
      duplicate,
      auraChanged: _totalAup(progress) !== auraTotalBefore,
      reason,
      delta,
      reservation,
      progress,
    };
  });
}

async function _entryReservationStatus({
  db,
  uid,
  attemptId,
  allowLegacyMigration = _legacyMigrationEnabled(),
}) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgressInTransaction({
      tx,
      serverRef: ref,
      legacyRef,
      clientWalletRef,
      allowLegacyMigration,
    });
    const progress = loaded.progress;
    const auraTotalBefore = _totalAup(progress);
    _grantRegisteredStarterAup(progress);
    const refunded = _reconcileExpiredReservations(progress);
    if (!loaded.existed || loaded.legacyMerged || refunded > 0) {
      _saveProgress(tx, ref, progress, { migratedFrom: loaded.migratedFrom });
    }
    const normalizedAttemptId = _eventId(attemptId);
    const reservation = normalizedAttemptId
      ? _findReservation(progress, normalizedAttemptId)
      : null;
    return {
      accepted: reservation != null,
      duplicate: false,
      auraChanged: _totalAup(progress) !== auraTotalBefore,
      reason: reservation ? 'accepted' : 'reservation_not_found',
      reservation,
      progress,
    };
  });
}

async function _walletForUser({
  db,
  uid,
  allowLegacyMigration = _legacyMigrationEnabled(),
}) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgressInTransaction({
      tx,
      serverRef: ref,
      legacyRef,
      clientWalletRef,
      allowLegacyMigration,
    });
    const progress = loaded.progress;
    const auraTotalBefore = _totalAup(progress);
    const starterBefore = progress.registeredStarterGranted;
    _grantRegisteredStarterAup(progress);
    const refunded = _reconcileExpiredReservations(progress);
    if (
      !loaded.existed ||
      loaded.legacyMerged ||
      loaded.normalizedCircuitAup ||
      refunded > 0 ||
      starterBefore !== progress.registeredStarterGranted
    ) {
      _saveProgress(tx, ref, progress, {
        migratedFrom: loaded.migratedFrom,
      });
    }
    return {
      exists: true,
      ...(loaded.migratedFrom ? { migrated: true } : {}),
      auraChanged: _totalAup(progress) !== auraTotalBefore,
      progress,
    };
  });
}

function economyRouter({ refreshLeaderboard } = {}) {
  const router = express.Router();
  const eventLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 40,
    standardHeaders: true,
    legacyHeaders: false,
  });

  router.get(
    '/wallet',
    requireRegisteredFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const db = _db();
      const result = await _walletForUser({ db, uid: req.auth.uid });
      if (result.auraChanged) {
        await _refreshLeaderboard({
          db,
          uid: req.auth.uid,
          refreshLeaderboard,
          requestId: req.requestId,
        });
      }
      const { auraChanged: _auraChanged, ...publicResult } = result;
      const catalogVersion = _catalogVersionForRequest(req);
      return res.json({
        ...publicResult,
        catalogVersion,
        progress: _snapshot(result.progress, catalogVersion),
      });
    }),
  );

  router.get(
    '/entries/:attemptId',
    eventLimiter,
    requireRegisteredFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const db = _db();
      const result = await _entryReservationStatus({
        db,
        uid: req.auth.uid,
        attemptId: req.params.attemptId,
      });
      if (result.auraChanged) {
        await _refreshLeaderboard({
          db,
          uid: req.auth.uid,
          refreshLeaderboard,
          requestId: req.requestId,
        });
      }
      const catalogVersion = _catalogVersionForRequest(req);
      return res.json({
        accepted: result.accepted,
        duplicate: result.duplicate,
        reason: result.reason,
        reservation: result.reservation || null,
        catalogVersion,
        progress: _snapshot(result.progress, catalogVersion),
      });
    }),
  );

  router.post(
    '/entries/reserve',
    eventLimiter,
    requireRegisteredFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const db = _db();
      const catalogVersion = _catalogVersionForRequest(req);
      const result = await _reserveEntry({
        db,
        uid: req.auth.uid,
        body: req.body || {},
        catalogVersion,
      });
      if (result.auraChanged) {
        await _refreshLeaderboard({
          db,
          uid: req.auth.uid,
          refreshLeaderboard,
          requestId: req.requestId,
        });
      }
      return res.json({
        accepted: result.accepted,
        duplicate: result.duplicate,
        reason: result.reason,
        delta: result.delta || 0,
        reservation: result.reservation || null,
        catalogVersion,
        progress: _snapshot(result.progress, catalogVersion),
      });
    }),
  );

  for (const transition of ['commit', 'refund', 'recover']) {
    router.post(
      `/entries/${transition}`,
      eventLimiter,
      requireRegisteredFirebaseAuth,
      _asyncHandler(async (req, res) => {
        const db = _db();
        const result = await _transitionEntryReservation({
          db,
          uid: req.auth.uid,
          body: req.body || {},
          transition,
        });
        if (result.auraChanged) {
          await _refreshLeaderboard({
            db,
            uid: req.auth.uid,
            refreshLeaderboard,
            requestId: req.requestId,
          });
        }
        const catalogVersion = _catalogVersionForRequest(req);
        return res.json({
          accepted: result.accepted,
          duplicate: result.duplicate,
          reason: result.reason,
          delta: result.delta || 0,
          reservation: result.reservation || null,
          catalogVersion,
          progress: _snapshot(result.progress, catalogVersion),
        });
      }),
    );
  }

  router.post(
    '/events',
    eventLimiter,
    requireRegisteredFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const db = _db();
      const catalogVersion = _catalogVersionForRequest(req);
      const result = await _applyEconomyEvent({
        db,
        uid: req.auth.uid,
        body: req.body || {},
        catalogVersion,
      });
      if (result.auraChanged) {
        await _refreshLeaderboard({
          db,
          uid: req.auth.uid,
          refreshLeaderboard,
          requestId: req.requestId,
        });
      }
      return res.json({
        accepted: result.accepted,
        duplicate: result.duplicate,
        reason: result.reason,
        delta: result.delta,
        payoutDelta: result.payoutDelta || 0,
        penaltyDelta: result.penaltyDelta || 0,
        clearRecorded: result.clearRecorded === true,
        matchRecorded: result.matchRecorded === true,
        catalogVersion,
        progress: _snapshot(result.progress, catalogVersion),
      });
    }),
  );

  return router;
}

module.exports = {
  economyRouter,
  SERVER_PROGRESS_COLLECTION,
  LEGACY_PROGRESS_COLLECTION,
  CLIENT_WALLET_COLLECTION,
  ECONOMY_RECEIPTS_COLLECTION,
  ENTRY_RECOVERY_DELAY_MS,
  ENTRY_RESERVATION_TTL_MS,
  _applyEconomyEvent,
  _baseProgress,
  _catalogVersionForRequest,
  _reserveEntry,
  _snapshot,
  _snapshotCircuitAup,
  _transitionEntryReservation,
  _entryReservationStatus,
  _refreshLeaderboard,
  _walletForUser,
};
