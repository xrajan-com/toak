// HTTP routes for the AUP economy, under /v1/economy. This file only speaks
// HTTP: the rules live in src/economy/.
const express = require('express');

const {
  isAccountDeletedError,
  requireRegisteredFirebaseAuth,
} = require('../security/firebase_auth');
const { playerRateLimit } = require('../security/rate_limit');
const { requestedCatalogVersion } = require('../economy/catalog');
const {
  entryReservationStatus,
  reserveEntry,
  transitionEntryReservation,
} = require('../economy/entries');
const { applyEconomyEvent } = require('../economy/events');
const { snapshot } = require('../economy/progress');
const { rankForUser } = require('../economy/rank');
const { firestore } = require('../economy/store');
const { walletForUser } = require('../economy/wallet');

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

function catalogVersionForRequest(req) {
  return requestedCatalogVersion(req.get('x-economy-catalog-version'));
}

/**
 * Updates the public leaderboard row after an Aura change. Never fails the
 * request: the wallet write is authoritative, and the next Aura-changing
 * request repairs a row that failed to update.
 */
async function refreshLeaderboardSafely({
  db,
  uid,
  refreshLeaderboard,
  requestId,
}) {
  if (typeof refreshLeaderboard !== 'function') return null;
  try {
    return await refreshLeaderboard({ db, uid });
  } catch (error) {
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

function economyRouter({ refreshLeaderboard } = {}) {
  const router = express.Router();
  // Counted per signed-in player, after authentication.
  const writeLimiter = playerRateLimit({ windowMs: 60 * 1000, max: 40 });

  // Runs an economy operation for the signed-in player, refreshes their
  // leaderboard row if their Aura moved, then answers with `respond`.
  const handle = (operation, respond) => _asyncHandler(async (req, res) => {
    const db = firestore();
    const catalogVersion = catalogVersionForRequest(req);
    const result = await operation({ req, db, uid: req.auth.uid, catalogVersion });
    if (result.auraChanged) {
      await refreshLeaderboardSafely({
        db,
        uid: req.auth.uid,
        refreshLeaderboard,
        requestId: req.requestId,
      });
    }
    return res.json({
      ...respond(result),
      catalogVersion,
      progress: snapshot(result.progress, catalogVersion),
    });
  });

  router.get(
    '/wallet',
    requireRegisteredFirebaseAuth,
    handle(
      ({ db, uid }) => walletForUser({ db, uid }),
      (result) => ({ exists: result.exists }),
    ),
  );

  router.get(
    '/rank',
    requireRegisteredFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const result = await rankForUser({ db: firestore(), uid: req.auth.uid });
      return res.json({ ok: true, ...result });
    }),
  );

  const entryResponse = (result) => ({
    accepted: result.accepted,
    duplicate: result.duplicate,
    reason: result.reason,
    delta: result.delta || 0,
    reservation: result.reservation || null,
  });

  router.get(
    '/entries/:attemptId',
    requireRegisteredFirebaseAuth,
    writeLimiter,
    handle(
      ({ req, db, uid }) => entryReservationStatus({
        db,
        uid,
        attemptId: req.params.attemptId,
      }),
      (result) => ({
        accepted: result.accepted,
        duplicate: result.duplicate,
        reason: result.reason,
        reservation: result.reservation || null,
      }),
    ),
  );

  router.post(
    '/entries/reserve',
    requireRegisteredFirebaseAuth,
    writeLimiter,
    handle(
      ({ req, db, uid, catalogVersion }) => reserveEntry({
        db,
        uid,
        body: req.body || {},
        catalogVersion,
      }),
      entryResponse,
    ),
  );

  for (const transition of ['commit', 'refund', 'recover']) {
    router.post(
      `/entries/${transition}`,
      requireRegisteredFirebaseAuth,
      writeLimiter,
      handle(
        ({ req, db, uid }) => transitionEntryReservation({
          db,
          uid,
          body: req.body || {},
          transition,
        }),
        entryResponse,
      ),
    );
  }

  router.post(
    '/events',
    requireRegisteredFirebaseAuth,
    writeLimiter,
    handle(
      ({ req, db, uid, catalogVersion }) => applyEconomyEvent({
        db,
        uid,
        body: req.body || {},
        catalogVersion,
      }),
      (result) => ({
        accepted: result.accepted,
        duplicate: result.duplicate,
        reason: result.reason,
        delta: result.delta,
        payoutDelta: result.payoutDelta || 0,
        penaltyDelta: result.penaltyDelta || 0,
        clearRecorded: result.clearRecorded === true,
        matchRecorded: result.matchRecorded === true,
      }),
    ),
  );

  return router;
}

module.exports = {
  catalogVersionForRequest,
  economyRouter,
  refreshLeaderboardSafely,
};
