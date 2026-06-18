const express = require('express');
const rateLimit = require('express-rate-limit');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const {
  firebaseAdminApp,
  requireFirebaseAuth,
} = require('../security/firebase_auth');

const SERVER_PROGRESS_COLLECTION = 'server_progress';
const LEGACY_PROGRESS_COLLECTION = 'campaign_progress';

const MAX_AUP_PER_CIRCUIT = 50000000;
const MAX_TOTAL_AUP = MAX_AUP_PER_CIRCUIT * 4;
const REGISTERED_STARTER_AUP = 10000;
const REWARDED_AD_AUP_BONUS = 2000;
const MAX_ENTRY_FEE = 10000000;
const MAX_CAMPAIGN_WIN_AUP = 10000000;
const MAX_REWARDED_ADS_PER_UTC_DAY = 30;
const CIRCUIT_FIELDS = ['oceaniaAup', 'euroAup', 'indiaAup', 'internationalAup'];

const QUIT_PENALTY_PERMILLE = 3;
const LOSS_PENALTY_PERMILLE = 1;

function _asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function _db() {
  return getFirestore(firebaseAdminApp());
}

function _clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function _int(value, { fallback = 0, min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return _clamp(Math.trunc(value), min, max);
}

function _group(raw) {
  if (raw === 'international') return 'international';
  if (raw === 'euro') return 'euro';
  if (raw === 'oceania' || raw === '7seas' || raw === 'seven_seas') {
    return 'oceania';
  }
  return 'india';
}

function _fieldForGroup(group) {
  switch (group) {
    case 'international':
      return 'internationalAup';
    case 'euro':
      return 'euroAup';
    case 'oceania':
      return 'oceaniaAup';
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

function _finishPermille({ finishRank, totalPlayers }) {
  if (totalPlayers <= 1) return 0;
  const r = _clamp(finishRank, 1, totalPlayers);
  const denom = Math.max(totalPlayers - 1, 1);
  return _clamp(Math.trunc(((r - 1) * 1000) / denom), 0, 1000);
}

function _baseProgress(data = {}) {
  return {
    schemaVersion: 1,
    indiaAup: _int(data.indiaAup, { min: 0, max: MAX_AUP_PER_CIRCUIT }),
    internationalAup: _int(data.internationalAup, {
      min: 0,
      max: MAX_AUP_PER_CIRCUIT,
    }),
    euroAup: _int(data.euroAup, { min: 0, max: MAX_AUP_PER_CIRCUIT }),
    oceaniaAup: _int(data.oceaniaAup, { min: 0, max: MAX_AUP_PER_CIRCUIT }),
    awardedEventIds: Array.isArray(data.awardedEventIds)
      ? data.awardedEventIds.filter((v) => typeof v === 'string').slice(0, 500)
      : [],
    registeredStarterGranted: data.registeredStarterGranted === true,
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
  };
}

function _snapshot(progress) {
  return {
    schemaVersion: 1,
    indiaAup: progress.indiaAup,
    internationalAup: progress.internationalAup,
    euroAup: progress.euroAup,
    oceaniaAup: progress.oceaniaAup,
    awardedEventIds: progress.awardedEventIds,
    registeredStarterGranted: progress.registeredStarterGranted,
    lastActiveAtMs: progress.lastActiveAtMs,
    prevActiveAtMs: progress.prevActiveAtMs,
    lastActiveDayKey: progress.lastActiveDayKey,
    activityScore: progress.activityScore,
    abandonedGames: progress.abandonedGames,
    matchesPlayed: progress.matchesPlayed,
    finishPermilleSum: progress.finishPermilleSum,
  };
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

async function _applyEconomyEvent({ db, uid, body }) {
  const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const legacyRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    let progress = _baseProgress(snap.data() || {});
    if (!snap.exists) {
      const legacySnap = await tx.get(legacyRef);
      progress = _baseProgress(legacySnap.data() || {});
    }
    _grantRegisteredStarterAup(progress);
    const action = typeof body.action === 'string' ? body.action : '';
    const group = _group(body.group);
    const eventId = _eventId(body.eventId);

    if (eventId && progress.appliedEventIds.includes(eventId)) {
      return { accepted: true, duplicate: true, delta: 0, progress };
    }

    let accepted = false;
    let delta = 0;

    if (action === 'rewarded_ad') {
      const today = _dayKeyUtc();
      if (progress.rewardedAdDayKey !== today) {
        progress.rewardedAdDayKey = today;
        progress.rewardedAdDayCount = 0;
      }
      if (progress.rewardedAdDayCount < MAX_REWARDED_ADS_PER_UTC_DAY) {
        delta = _addAup(progress, group, REWARDED_AD_AUP_BONUS);
        progress.rewardedAdDayCount += 1;
        accepted = delta > 0;
      }
    } else if (action === 'entry_fee') {
      const amount = _int(body.amount, { min: 0, max: MAX_ENTRY_FEE });
      const paid = _deductAup(progress, group, amount);
      accepted = paid >= 0;
      delta = paid >= 0 ? -paid : 0;
    } else if (action === 'campaign_win') {
      const amount = _int(body.amount, { min: 0, max: MAX_CAMPAIGN_WIN_AUP });
      if (eventId && !progress.awardedEventIds.includes(eventId)) {
        delta = _addAup(progress, group, amount);
        progress.awardedEventIds.push(eventId);
        accepted = delta > 0;
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
      accepted = true;
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
      accepted = true;
    }

    if (!accepted) {
      return { accepted: false, duplicate: false, delta: 0, progress };
    }

    if (eventId) {
      progress.appliedEventIds.push(eventId);
      progress.appliedEventIds = progress.appliedEventIds.slice(-500);
    }
    _touchActivity(progress);
    tx.set(ref, {
      ...progress,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { accepted, duplicate: false, delta, progress };
  });
}

function economyRouter() {
  const router = express.Router();
  const eventLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 40,
    standardHeaders: true,
    legacyHeaders: false,
  });

  router.get(
    '/wallet',
    requireFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const db = _db();
      const ref = db.collection(SERVER_PROGRESS_COLLECTION).doc(req.auth.uid);
      const snap = await ref.get();
      if (!snap.exists) {
        const legacySnap = await db
          .collection(LEGACY_PROGRESS_COLLECTION)
          .doc(req.auth.uid)
          .get();
        if (!legacySnap.exists) {
          const progress = _grantRegisteredStarterAup(_baseProgress({}));
          await ref.set(
            {
              ...progress,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          return res.json({
            exists: true,
            progress: _snapshot(progress),
          });
        }
        const progress = _grantRegisteredStarterAup(
          _baseProgress(legacySnap.data() || {}),
        );
        await ref.set(
          {
            ...progress,
            migratedFrom: LEGACY_PROGRESS_COLLECTION,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return res.json({
          exists: true,
          migrated: true,
          progress: _snapshot(progress),
        });
      }
      const progress = _grantRegisteredStarterAup(
        _baseProgress(snap.data() || {}),
      );
      if (
        progress.registeredStarterGranted !==
        snap.data()?.registeredStarterGranted
      ) {
        await ref.set(
          {
            ...progress,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      return res.json({
        exists: snap.exists,
        progress: _snapshot(progress),
      });
    }),
  );

  router.post(
    '/events',
    eventLimiter,
    requireFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const result = await _applyEconomyEvent({
        db: _db(),
        uid: req.auth.uid,
        body: req.body || {},
      });
      return res.json({
        accepted: result.accepted,
        duplicate: result.duplicate,
        delta: result.delta,
        progress: _snapshot(result.progress),
      });
    }),
  );

  return router;
}

module.exports = {
  economyRouter,
  SERVER_PROGRESS_COLLECTION,
};
