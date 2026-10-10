// A player's wallet document ("progress") and the arithmetic on it.
// Pure functions: no Firestore here. store.js loads and saves the document;
// wallet.js, entries.js and events.js are the operations that change it.
const crypto = require('node:crypto');

const {
  ENTRY_RESERVATION_TTL_MS,
  MAX_AUP_PER_CIRCUIT,
  MAX_ENTRY_FEE,
  MAX_STORED_ENTRY_RESERVATIONS,
  MAX_TOTAL_AUP,
  MIGRATION_COMPLETE_VERSION,
  REGISTERED_STARTER_AUP,
  normalizeCircuitAup,
} = require('./constants');
const {
  ECONOMY_CATALOG_VERSION,
  requestedCatalogVersion,
} = require('./catalog');

// Order matters: the starter grant gives the remainder to the last field,
// and whole-wallet penalties are taken in this order.
const CIRCUIT_FIELDS = Object.freeze([
  'northAmericaAup',
  'oceaniaAup',
  'euroAup',
  'indiaAup',
  'internationalAup',
]);
const MAX_TIMESTAMP_MS = 9999999999999;
const MAX_COUNTER = 2000000000;

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function int(value, { fallback = 0, min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return clamp(Math.trunc(value), min, max);
}

/** A circuit name as clients send it, or null. Old spellings still map. */
function circuit(raw) {
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

function fieldForCircuit(group) {
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

function totalAup(progress) {
  return CIRCUIT_FIELDS.reduce((sum, field) => sum + int(progress[field]), 0);
}

function dayKeyUtc(ms = Date.now()) {
  return new Date(ms).toISOString().slice(0, 10);
}

/** A trimmed id of at most 120 characters, or '' (event, attempt, campaign ids). */
function cleanId(raw) {
  if (typeof raw !== 'string') return '';
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length > 120) return '';
  return trimmed;
}

function receiptId(uid, eventId) {
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
  const attemptId = cleanId(raw.attemptId);
  const campaignId = cleanId(raw.campaignId);
  const group = circuit(raw.group);
  const amount = int(raw.amount, { min: 0, max: MAX_ENTRY_FEE });
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
    catalogVersion: typeof raw.catalogVersion === 'string'
      ? requestedCatalogVersion(raw.catalogVersion)
      : ECONOMY_CATALOG_VERSION,
    createdAtMs: int(raw.createdAtMs, { min: 0, max: MAX_TIMESTAMP_MS }),
    updatedAtMs: int(raw.updatedAtMs, { min: 0, max: MAX_TIMESTAMP_MS }),
  };
}

/** Finishing place as thousandths of the field: 0 for first, 1000 for last. */
function finishPermille({ finishRank, totalPlayers }) {
  if (totalPlayers <= 1) return 0;
  const r = clamp(finishRank, 1, totalPlayers);
  const denom = Math.max(totalPlayers - 1, 1);
  return clamp(Math.trunc(((r - 1) * 1000) / denom), 0, 1000);
}

/**
 * The wallet as the server works with it: every field present, typed and
 * bounded, whatever the stored document holds.
 */
function baseProgress(data = {}) {
  const circuitAup = normalizeCircuitAup(data);
  return {
    schemaVersion: 1,
    walletVersion: int(data.walletVersion, {
      min: 0,
      max: Number.MAX_SAFE_INTEGER,
    }),
    ...circuitAup,
    awardedEventIds: _stringList(data.awardedEventIds, 500),
    cleared: _stringList(data.cleared, 500),
    mainEventsCleared: _stringList(data.mainEventsCleared, 200),
    registeredStarterGranted: data.registeredStarterGranted === true,
    legacyMigrationVersion: int(data.legacyMigrationVersion, {
      min: 0,
      max: MIGRATION_COMPLETE_VERSION,
    }),
    appliedEventIds: Array.isArray(data.appliedEventIds)
      ? data.appliedEventIds.filter((v) => typeof v === 'string').slice(-500)
      : [],
    lastActiveAtMs: int(data.lastActiveAtMs, { min: 0, max: MAX_TIMESTAMP_MS }),
    prevActiveAtMs: int(data.prevActiveAtMs, { min: 0, max: MAX_TIMESTAMP_MS }),
    lastActiveDayKey: typeof data.lastActiveDayKey === 'string'
      ? data.lastActiveDayKey.slice(0, 16)
      : '',
    activityScore: int(data.activityScore, { min: 0, max: 10000 }),
    abandonedGames: int(data.abandonedGames, { min: 0, max: MAX_COUNTER }),
    matchesPlayed: int(data.matchesPlayed, { min: 0, max: MAX_COUNTER }),
    finishPermilleSum: int(data.finishPermilleSum, {
      min: 0,
      max: MAX_COUNTER,
    }),
    rewardedAdDayKey: typeof data.rewardedAdDayKey === 'string'
      ? data.rewardedAdDayKey.slice(0, 16)
      : '',
    rewardedAdDayCount: int(data.rewardedAdDayCount, { min: 0, max: 100000 }),
    entryReservations: Array.isArray(data.entryReservations)
      ? data.entryReservations
        .map(_reservation)
        .filter(Boolean)
        .slice(-MAX_STORED_ENTRY_RESERVATIONS)
      : [],
  };
}

/** What a client is shown of its wallet. */
function snapshot(progress, catalogVersion = ECONOMY_CATALOG_VERSION) {
  return {
    schemaVersion: 1,
    walletVersion: progress.walletVersion,
    indiaAup: progress.indiaAup,
    internationalAup: progress.internationalAup,
    euroAup: progress.euroAup,
    oceaniaAup: progress.oceaniaAup,
    northAmericaAup: progress.northAmericaAup,
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

/* ------------------------------ balances ------------------------------ */

/** Adds AUP to one circuit up to its cap; returns what was actually added. */
function addAup(progress, group, amount) {
  const field = fieldForCircuit(group);
  const before = progress[field];
  progress[field] = clamp(progress[field] + amount, 0, MAX_AUP_PER_CIRCUIT);
  return progress[field] - before;
}

/** Takes AUP from one circuit; returns the amount, or -1 if it cannot pay. */
function deductAup(progress, group, amount) {
  if (amount <= 0) return 0;
  const field = fieldForCircuit(group);
  if (progress[field] < amount) return -1;
  progress[field] = clamp(progress[field] - amount, 0, MAX_AUP_PER_CIRCUIT);
  return amount;
}

function _deductAupTotal(progress, amount) {
  let remaining = int(amount, { min: 0, max: MAX_TOTAL_AUP });
  if (remaining <= 0) return 0;
  const before = totalAup(progress);
  for (const field of CIRCUIT_FIELDS) {
    const take = Math.min(progress[field], remaining);
    progress[field] -= take;
    remaining -= take;
    if (remaining <= 0) break;
  }
  return before - totalAup(progress);
}

/** Takes a share of the whole wallet; returns the AUP taken. */
function deductPermille(progress, permille) {
  const total = totalAup(progress);
  const amount = Math.trunc((total * permille) / 1000);
  return _deductAupTotal(progress, amount);
}

function grantRegisteredStarterAup(progress) {
  if (progress.registeredStarterGranted) return progress;
  const total = totalAup(progress);
  if (total <= 0) {
    let remaining = REGISTERED_STARTER_AUP;
    CIRCUIT_FIELDS.forEach((field, index) => {
      const grant = index === CIRCUIT_FIELDS.length - 1
        ? remaining
        : Math.trunc(REGISTERED_STARTER_AUP / CIRCUIT_FIELDS.length);
      progress[field] = clamp(progress[field] + grant, 0, MAX_AUP_PER_CIRCUIT);
      remaining -= grant;
    });
  }
  progress.registeredStarterGranted = true;
  return progress;
}

/* --------------------------- career and stats --------------------------- */

function recordCampaignClear(progress, event) {
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

function recordAward(progress, campaignId) {
  if (!progress.awardedEventIds.includes(campaignId)) {
    progress.awardedEventIds.push(campaignId);
    progress.awardedEventIds = progress.awardedEventIds.slice(-500);
  }
}

/** Counts one finished match: played, finishing place, and quits. */
function recordMatch(progress, { finishRank, totalPlayers, abandoned = false }) {
  progress.matchesPlayed = clamp(progress.matchesPlayed + 1, 0, MAX_COUNTER);
  progress.finishPermilleSum = clamp(
    progress.finishPermilleSum + finishPermille({ finishRank, totalPlayers }),
    0,
    MAX_COUNTER,
  );
  if (abandoned) {
    progress.abandonedGames = clamp(progress.abandonedGames + 1, 0, MAX_COUNTER);
  }
}

function touchActivity(progress) {
  const nowMs = Date.now();
  if (progress.lastActiveAtMs > 0 && nowMs > progress.lastActiveAtMs) {
    progress.prevActiveAtMs = progress.lastActiveAtMs;
  }
  progress.lastActiveAtMs = nowMs;

  const today = dayKeyUtc(nowMs);
  if (progress.lastActiveDayKey !== today) {
    progress.activityScore = clamp(progress.activityScore + 1, 0, 10000);
    progress.lastActiveDayKey = today;
  }
}

/* ---------------------------- entry reservations ---------------------------- */

function isActiveReservation(reservation) {
  return reservation.status === 'reserved' || reservation.status === 'committed';
}

function findReservation(progress, attemptId) {
  return progress.entryReservations.find(
    (reservation) => reservation.attemptId === attemptId,
  );
}

/** Stores a reservation; finished ones are pruned first, active ones never. */
function putReservation(progress, reservation) {
  const all = [
    ...progress.entryReservations.filter(
      (candidate) => candidate.attemptId !== reservation.attemptId,
    ),
    reservation,
  ];
  const active = all.filter(isActiveReservation);
  const finished = all.filter((candidate) => !isActiveReservation(candidate));
  const finishedSlots = Math.max(
    0,
    MAX_STORED_ENTRY_RESERVATIONS - active.length,
  );
  progress.entryReservations = [
    ...(finishedSlots > 0 ? finished.slice(-finishedSlots) : []),
    ...active,
  ];
}

/** Refunds entries reserved but never started within the hold; returns AUP refunded. */
function reconcileExpiredReservations(progress, nowMs = Date.now()) {
  let refunded = 0;
  for (const reservation of progress.entryReservations) {
    if (
      reservation.status !== 'reserved' ||
      reservation.createdAtMs <= 0 ||
      nowMs - reservation.createdAtMs < ENTRY_RESERVATION_TTL_MS
    ) {
      continue;
    }
    refunded += addAup(progress, reservation.group, reservation.amount);
    reservation.status = 'refunded';
    reservation.updatedAtMs = nowMs;
  }
  return refunded;
}

/** Marks a started or reserved entry as finished, if there is one. */
function settleReservation(progress, attemptId) {
  const reservation = findReservation(progress, cleanId(attemptId));
  if (reservation && isActiveReservation(reservation)) {
    reservation.status = 'settled';
    reservation.updatedAtMs = Date.now();
  }
}

module.exports = {
  CIRCUIT_FIELDS,
  addAup,
  baseProgress,
  circuit,
  clamp,
  cleanId,
  deductAup,
  deductPermille,
  finishPermille,
  findReservation,
  grantRegisteredStarterAup,
  int,
  isActiveReservation,
  putReservation,
  receiptId,
  reconcileExpiredReservations,
  recordAward,
  recordCampaignClear,
  recordMatch,
  settleReservation,
  snapshot,
  totalAup,
  touchActivity,
};
