const express = require('express');
const rateLimit = require('express-rate-limit');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const {
  firebaseAdminApp,
  requireFirebaseAuth,
} = require('../security/firebase_auth');
const { SERVER_PROGRESS_COLLECTION } = require('./economy');

const LEADERBOARD_COLLECTION = 'leaderboard';
const USERS_COLLECTION = 'users';

const AUP_PER_AURA = 1000000;
const AURA_MILLI_PER_AURA = 1000;
const MAX_AUP_PER_CIRCUIT = 50000000;
const MAX_TOTAL_AUP = MAX_AUP_PER_CIRCUIT * 4;
const MAX_TOTAL_AURA_MILLI = 200000;

const AURA_MILLI_MULTIPLIER = 2000000000;
const ACTIVITY_MULTIPLIER = 100000;
const EFFICIENCY_MULTIPLIER = 45000;
const FINISH_MULTIPLIER = 50000;

function _asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function _db() {
  return getFirestore(firebaseAdminApp());
}

function _clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function _numInt(value, { fallback = 0, min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return _clamp(fallback, min, max);
  }
  return _clamp(Math.trunc(value), min, max);
}

function _auraMilliFromAup(aup) {
  if (aup <= 0) return 0;
  const rounded = (aup * AURA_MILLI_PER_AURA) + Math.floor(AUP_PER_AURA / 2);
  return _clamp(Math.floor(rounded / AUP_PER_AURA), 0, MAX_TOTAL_AURA_MILLI);
}

function _rankScore({
  auraMilli,
  auraMilliPerMatch,
  avgFinishPermille,
  activityScore,
  lastActiveDay,
}) {
  const eff = _clamp(auraMilliPerMatch, 0, 20000);
  const finishSkill = _clamp(1000 - avgFinishPermille, 0, 1000);
  return (
    (auraMilli * AURA_MILLI_MULTIPLIER) +
    (eff * EFFICIENCY_MULTIPLIER) +
    (finishSkill * FINISH_MULTIPLIER) +
    (activityScore * ACTIVITY_MULTIPLIER) +
    lastActiveDay
  );
}

function _progressStats(data) {
  const indiaAup = _numInt(data?.indiaAup, {
    min: 0,
    max: MAX_AUP_PER_CIRCUIT,
  });
  const internationalAup = _numInt(data?.internationalAup, {
    min: 0,
    max: MAX_AUP_PER_CIRCUIT,
  });
  const euroAup = _numInt(data?.euroAup, {
    min: 0,
    max: MAX_AUP_PER_CIRCUIT,
  });
  const oceaniaAup = _numInt(data?.oceaniaAup, {
    min: 0,
    max: MAX_AUP_PER_CIRCUIT,
  });
  const totalAup = _clamp(
    indiaAup + internationalAup + euroAup + oceaniaAup,
    0,
    MAX_TOTAL_AUP,
  );
  const auraMilli = _auraMilliFromAup(totalAup);

  const matchesPlayed = _numInt(data?.matchesPlayed, {
    min: 0,
    max: 2000000000,
  });
  const finishPermilleSum = _numInt(data?.finishPermilleSum, {
    min: 0,
    max: 2000000000,
  });
  const avgFinishPermille = matchesPlayed <= 0
    ? 0
    : _clamp(Math.trunc(finishPermilleSum / matchesPlayed), 0, 1000);
  const auraMilliPerMatch = matchesPlayed <= 0
    ? 0
    : _clamp(Math.trunc(auraMilli / matchesPlayed), 0, 100000);
  const activityScore = _numInt(data?.activityScore, { min: 0, max: 10000 });
  const lastActiveAtMs = _numInt(data?.lastActiveAtMs, {
    min: 0,
    max: 9999999999999,
  });
  const lastActiveDay = lastActiveAtMs <= 0
    ? 0
    : _clamp(Math.trunc(lastActiveAtMs / 86400000), 0, 1000000000);

  const rankScore = _rankScore({
    auraMilli,
    auraMilliPerMatch,
    avgFinishPermille,
    activityScore,
    lastActiveDay,
  });

  return {
    auraMilli,
    totalAup,
    activityScore,
    matchesPlayed,
    auraMilliPerMatch,
    avgFinishPermille,
    lastActiveDay,
    rankScore,
  };
}

function _cleanDisplayName(raw) {
  if (typeof raw !== 'string') return '';
  const trimmed = raw.trim();
  if (!trimmed) return '';
  return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
}

async function _displayNameFor(db, uid, auth) {
  try {
    const snap = await db.collection(USERS_COLLECTION).doc(uid).get();
    const data = snap.data();
    const profileName = _cleanDisplayName(data?.displayName);
    if (profileName) return profileName;
    const username = _cleanDisplayName(data?.username);
    if (username) return username;
  } catch (_) {
    // Fall back to verified token claims below.
  }

  const tokenName = _cleanDisplayName(auth?.name);
  if (tokenName) return tokenName;

  const email = typeof auth?.email === 'string' ? auth.email.trim() : '';
  if (email.includes('@')) {
    const localPart = _cleanDisplayName(email.split('@')[0]);
    if (localPart) return localPart;
  }

  return 'Player';
}

async function _qualifiesForTop10(db, uid, rankScore) {
  const snap = await db
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('rankScore', 'desc')
    .limit(10)
    .get();

  const docs = snap.docs;
  if (docs.some((doc) => doc.id === uid)) return true;
  if (docs.length < 10) return true;

  const minTop10Score = _numInt(docs[docs.length - 1].get('rankScore'), {
    fallback: -1,
    min: -1,
  });
  return rankScore >= minTop10Score;
}

async function _pruneLeaderboard(db) {
  const snap = await db
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('rankScore', 'desc')
    .limit(25)
    .get();

  if (snap.docs.length <= 10) return;

  const batch = db.batch();
  for (const doc of snap.docs.slice(10)) {
    batch.delete(doc.ref);
  }
  await batch.commit();
}

function leaderboardRouter() {
  const router = express.Router();

  const syncLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    standardHeaders: true,
    legacyHeaders: false,
  });

  router.post(
    '/sync',
    syncLimiter,
    requireFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const uid = req.auth.uid;
      const db = _db();
      const leaderboardRef = db.collection(LEADERBOARD_COLLECTION).doc(uid);

      const progressSnap = await db
        .collection(SERVER_PROGRESS_COLLECTION)
        .doc(uid)
        .get();
      const progress = progressSnap.data();
      const stats = _progressStats(progress);

      if (!progressSnap.exists || stats.auraMilli <= 0) {
        await leaderboardRef.delete();
        await _pruneLeaderboard(db);
        return res.json({
          synced: false,
          removed: true,
          reason: 'no_aura',
        });
      }

      if (!(await _qualifiesForTop10(db, uid, stats.rankScore))) {
        await leaderboardRef.delete();
        await _pruneLeaderboard(db);
        return res.json({
          synced: false,
          removed: true,
          reason: 'below_top_10',
        });
      }

      const displayName = await _displayNameFor(db, uid, req.auth);
      await leaderboardRef.set(
        {
          displayName,
          ...stats,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await _pruneLeaderboard(db);

      return res.json({
        synced: true,
        removed: false,
        entry: {
          displayName,
          ...stats,
        },
      });
    }),
  );

  return router;
}

module.exports = {
  leaderboardRouter,
  _progressStats,
};
