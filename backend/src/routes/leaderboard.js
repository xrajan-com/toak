const express = require('express');
const { FieldValue } = require('firebase-admin/firestore');

const {
  assertAccountActiveInTransaction,
  isAccountDeletedError,
  requireRegisteredFirebaseAuth,
} = require('../security/firebase_auth');
const {
  AUP_PER_AURA,
  AURA_MILLI_PER_AURA,
  MAX_AUP_PER_CIRCUIT,
  MAX_TOTAL_AUP,
  MAX_TOTAL_AURA_MILLI,
  normalizeCircuitAup,
} = require('../economy/constants');
const {
  isOpaqueLeaderboardDocumentId,
  leaderboardDocumentId,
} = require('../leaderboard_identity');
const { SERVER_PROGRESS_COLLECTION } = require('../economy/store');
const { fortsClearedCount } = require('../economy/catalog');
const { playerRateLimit } = require('../security/rate_limit');

const LEADERBOARD_COLLECTION = 'leaderboard';
// Trailblazers: the ten players who have cleared the most of the 500 forts.
// Its own top-10 collection, because the Aura board above only holds the
// Aura top ten and a fort-heavy player may not be in it.
const TRAILBLAZERS_COLLECTION = 'trailblazers';
// Orders by forts, then Aura: forts * (max Aura milli + 1) + Aura milli.
const TRAIL_FORT_MULTIPLIER = MAX_TOTAL_AURA_MILLI + 1;
const USERS_COLLECTION = 'users';

const AURA_MILLI_MULTIPLIER = 2000000000;
const ACTIVITY_MULTIPLIER = 100000;
const EFFICIENCY_MULTIPLIER = 45000;
const FINISH_MULTIPLIER = 50000;
const LEADERBOARD_MIGRATION_READ_LIMIT = 25;
const LEADERBOARD_MIGRATION_MAX_PASSES = 100;
const PUBLIC_LEADERBOARD_FIELDS = Object.freeze([
  'displayName',
  'aura',
  'auraMilli',
  'totalAup',
  'activityScore',
  'matchesPlayed',
  'auraMilliPerMatch',
  'avgFinishPermille',
  'lastActiveDay',
  'rankScore',
  'updatedAt',
]);

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
  const {
    indiaAup,
    internationalAup,
    euroAup,
    oceaniaAup,
    northAmericaAup,
  } = normalizeCircuitAup(data);
  const totalAup = _clamp(
    indiaAup + internationalAup + euroAup + oceaniaAup + northAmericaAup,
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

function _displayNameFor(profile) {
  const profileName = _cleanDisplayName(profile?.displayName);
  if (profileName) return profileName;
  const username = _cleanDisplayName(profile?.username);
  if (username) return username;
  return 'Player';
}

function _publicLeaderboardProjection(data) {
  const projection = {};
  for (const field of PUBLIC_LEADERBOARD_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(data || {}, field)) {
      projection[field] = data[field];
    }
  }
  return projection;
}

async function _qualifiesForTop10(db, uid, auraMilli) {
  const publicId = leaderboardDocumentId(uid);
  const snap = await db
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('auraMilli', 'desc')
    .limit(10)
    .get();

  const docs = snap.docs;
  // Accept the legacy uid-keyed row while a user is being migrated. The sync
  // transaction below removes it before publishing the opaque row.
  if (docs.some((doc) => doc.id === publicId || doc.id === uid)) return true;
  if (docs.length < 10) return true;

  const minTop10Aura = _numInt(docs[docs.length - 1].get('auraMilli'), {
    fallback: -1,
    min: -1,
  });
  return auraMilli > minTop10Aura;
}

async function _pruneLeaderboard(db) {
  // The leaderboard is capped at ten rows, but read a larger bounded window so
  // a deployment also cleans up historical overflow. Repeat bounded passes
  // because older deployments allowed more than one window of uid-keyed rows.
  const migrationQuery = db
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('auraMilli', 'desc')
    .limit(LEADERBOARD_MIGRATION_READ_LIMIT);

  for (let pass = 0; pass < LEADERBOARD_MIGRATION_MAX_PASSES; pass += 1) {
    await db.runTransaction(async (tx) => {
      const migrationSnap = await tx.get(migrationQuery);
      const legacyDocs = migrationSnap.docs.filter(
        (doc) => !isOpaqueLeaderboardDocumentId(doc.id),
      );
      if (legacyDocs.length === 0) return;

      // Read every possible destination before writing, as required by
      // Firestore transactions. An existing opaque row wins over a stale
      // legacy duplicate.
      const destinations = legacyDocs.map((doc) =>
        db.collection(LEADERBOARD_COLLECTION).doc(
          leaderboardDocumentId(doc.id),
        ));
      const destinationSnaps = await Promise.all(
        destinations.map((ref) => tx.get(ref)),
      );

      for (let index = 0; index < legacyDocs.length; index += 1) {
        if (!destinationSnaps[index].exists) {
          tx.set(
            destinations[index],
            _publicLeaderboardProjection(legacyDocs[index].data()),
          );
        }
        tx.delete(legacyDocs[index].ref);
      }
    });

    // Re-query after migration because document ids and duplicate removal may
    // have changed the result set. Deleting overflow reveals the next legacy
    // window on the following pass.
    const snap = await migrationQuery.get();
    if (snap.docs.length <= 10) return;

    const batch = db.batch();
    for (const doc of snap.docs.slice(10)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  throw new Error('Leaderboard cleanup exceeded its bounded migration limit.');
}

async function _syncLeaderboard({ db, uid }) {
  const publicId = leaderboardDocumentId(uid);
  const leaderboardRef = db.collection(LEADERBOARD_COLLECTION).doc(publicId);
  const legacyLeaderboardRef = db.collection(LEADERBOARD_COLLECTION).doc(uid);
  const progressRef = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const profileRef = db.collection(USERS_COLLECTION).doc(uid);
  const top10Query = db
    .collection(LEADERBOARD_COLLECTION)
    .orderBy('auraMilli', 'desc')
    .limit(10);

  const result = await db.runTransaction(async (tx) => {
    // This read is part of the same transaction as the leaderboard write. If
    // deletion creates the tombstone concurrently, Firestore retries this
    // transaction and the retry rejects instead of recreating the entry.
    await assertAccountActiveInTransaction({ tx, db, uid });
    const progressSnap = await tx.get(progressRef);
    const top10Snap = await tx.get(top10Query);
    const legacyLeaderboardSnap = await tx.get(legacyLeaderboardRef);
    const progress = progressSnap.data();
    const stats = _progressStats(progress);
    const currentDocs = top10Snap.docs.filter(
      (doc) => doc.id === publicId || doc.id === uid,
    );
    if (
      legacyLeaderboardSnap.exists &&
      !currentDocs.some((doc) => doc.id === uid)
    ) {
      currentDocs.push(legacyLeaderboardSnap);
    }

    if (!progressSnap.exists || stats.auraMilli <= 0) {
      for (const doc of currentDocs) tx.delete(doc.ref);
      return {
        synced: false,
        removed: currentDocs.length > 0,
        reason: 'no_aura',
      };
    }

    const qualifies = currentDocs.length > 0 ||
      top10Snap.docs.length < 10 ||
      stats.auraMilli > _numInt(
        top10Snap.docs[top10Snap.docs.length - 1]?.get('auraMilli'),
        { fallback: -1, min: -1 },
      );
    if (!qualifies) {
      return {
        synced: false,
        removed: false,
        reason: 'below_top_10',
      };
    }

    const profileSnap = await tx.get(profileRef);
    const displayName = _displayNameFor(profileSnap.data());
    const legacyDoc = currentDocs.find((doc) => doc.id === uid);
    if (legacyDoc) tx.delete(legacyLeaderboardRef);

    // The collection itself contains only the Aura top 10. A newcomer must
    // beat the current cutoff (ties keep the incumbent), and the replacement
    // happens atomically so concurrent users cannot grow it past ten rows.
    if (currentDocs.length === 0 && top10Snap.docs.length >= 10) {
      tx.delete(top10Snap.docs[top10Snap.docs.length - 1].ref);
    }
    tx.set(
      leaderboardRef,
      {
        displayName,
        ...stats,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      synced: true,
      removed: false,
      entry: {
        displayName,
        ...stats,
      },
    };
  });

  return result;
}

function _trailScore(fortsCleared, auraMilli) {
  return (
    _clamp(fortsCleared, 0, 1000) * TRAIL_FORT_MULTIPLIER +
    _clamp(auraMilli, 0, MAX_TOTAL_AURA_MILLI)
  );
}

/**
 * Keeps the player's Trailblazers row current: written while they are in the
 * top ten by forts cleared (ties go to more Aura), removed when they have
 * none. Same shape and rules as _syncLeaderboard, ranked by trailScore.
 */
async function _syncTrailblazers({ db, uid }) {
  const publicId = leaderboardDocumentId(uid);
  const rowRef = db.collection(TRAILBLAZERS_COLLECTION).doc(publicId);
  const progressRef = db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
  const profileRef = db.collection(USERS_COLLECTION).doc(uid);
  const top10Query = db
    .collection(TRAILBLAZERS_COLLECTION)
    .orderBy('trailScore', 'desc')
    .limit(10);

  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const progressSnap = await tx.get(progressRef);
    const top10Snap = await tx.get(top10Query);
    const rowSnap = await tx.get(rowRef);
    const progress = progressSnap.data();
    const fortsCleared = fortsClearedCount(progress?.cleared);
    const { auraMilli } = _progressStats(progress);
    const trailScore = _trailScore(fortsCleared, auraMilli);

    if (!progressSnap.exists || fortsCleared <= 0) {
      if (rowSnap.exists) tx.delete(rowRef);
      return { synced: false, removed: rowSnap.exists, reason: 'no_forts' };
    }

    const inTop10 = top10Snap.docs.some((doc) => doc.id === publicId);
    const cutoff = _numInt(
      top10Snap.docs[top10Snap.docs.length - 1]?.get('trailScore'),
      { fallback: -1, min: -1 },
    );
    const qualifies = rowSnap.exists || inTop10 ||
      top10Snap.docs.length < 10 || trailScore > cutoff;
    if (!qualifies) {
      return { synced: false, removed: false, reason: 'below_top_10' };
    }

    const profileSnap = await tx.get(profileRef);
    const displayName = _displayNameFor(profileSnap.data());
    // A newcomer replaces the current tenth row in the same transaction, so
    // the collection never grows past ten.
    if (!rowSnap.exists && !inTop10 && top10Snap.docs.length >= 10) {
      tx.delete(top10Snap.docs[top10Snap.docs.length - 1].ref);
    }
    const entry = { displayName, fortsCleared, auraMilli, trailScore };
    tx.set(rowRef, { ...entry, updatedAt: FieldValue.serverTimestamp() });
    return { synced: true, removed: false, entry };
  });
}

/**
 * Refreshes both public boards after a player's Aura or forts change. Each
 * board is tried even if the other fails; the first failure is rethrown so
 * the caller can log it.
 */
async function _refreshPublicBoards({ db, uid }) {
  const [aura, trail] = await Promise.allSettled([
    _syncLeaderboard({ db, uid }),
    _syncTrailblazers({ db, uid }),
  ]);
  if (aura.status === 'rejected') throw aura.reason;
  if (trail.status === 'rejected') throw trail.reason;
  return { aura: aura.value, trailblazers: trail.value };
}

function leaderboardRouter() {
  const router = express.Router();

  const syncLimiter = playerRateLimit({ windowMs: 60 * 1000, max: 30 });

  router.post(
    '/sync',
    requireRegisteredFirebaseAuth,
    syncLimiter,
    _asyncHandler(async (req, res) => {
      // Kept as a read-free compatibility endpoint for older clients. Aura
      // mutations now maintain the projection; viewing it must not spend
      // Firestore reads or writes.
      return res.json({
        synced: false,
        removed: false,
        reason: 'event_driven',
      });
    }),
  );

  return router;
}

module.exports = {
  LEADERBOARD_COLLECTION,
  TRAILBLAZERS_COLLECTION,
  USERS_COLLECTION,
  leaderboardRouter,
  _progressStats,
  _pruneLeaderboard,
  _qualifiesForTop10,
  _refreshPublicBoards,
  _syncLeaderboard,
  _syncTrailblazers,
  _trailScore,
};
