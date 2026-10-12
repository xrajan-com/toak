// Entering a table. A fort or title match is paid for in three steps, so a
// crash before the cards are dealt never loses AUP:
//   reserve  the catalog entry fee is taken and held
//   commit   the game has started; the fee is spent
//   settle   the result arrives (events.js)
// A reservation that never starts is refunded after an hour; a started game
// with no result is closed as abandoned ("recover").
const {
  ECONOMY_CATALOG_VERSION,
  campaignEvent,
} = require('./catalog');
const {
  ECONOMY_RULES_VERSION,
  ENTRY_RECOVERY_DELAY_MS,
  MAX_ENTRY_FEE,
} = require('./constants');
const {
  addAup,
  cleanId,
  deductAup,
  findReservation,
  int,
  isActiveReservation,
  putReservation,
  reconcileExpiredReservations,
  recordMatch,
  touchActivity,
} = require('./progress');
const { saveProgress, withWallet } = require('./store');

function _entryPrerequisitesMet(progress, event) {
  if (event.kind === 'fort') {
    // Forts may be entered in any order. The reservation still charges the
    // catalog fee against the player's circuit wallet.
    return true;
  }
  if (event.kind === 'main') {
    return Array.isArray(event.requiredFortIds) &&
      event.requiredFortIds.every((id) => progress.cleared.includes(id));
  }
  return false;
}

async function reserveEntry({
  db,
  uid,
  body,
  catalogVersion = ECONOMY_CATALOG_VERSION,
}) {
  return withWallet(db, uid, ({ tx, ref, progress, auraChanged }) => {
    const expiredRefund = reconcileExpiredReservations(progress);
    const refuse = (reason, extra = {}) => {
      if (expiredRefund > 0) saveProgress(tx, ref, progress);
      return {
        accepted: false,
        duplicate: false,
        auraChanged: auraChanged(),
        reason,
        ...extra,
        progress,
      };
    };

    const attemptId = cleanId(body.attemptId);
    const campaignId = cleanId(body.campaignId);
    const event = campaignEvent(campaignId, catalogVersion);
    if (!attemptId) return refuse('attempt_id_required');
    if (!event) return refuse('invalid_campaign_event');

    const existing = findReservation(progress, attemptId);
    if (existing) {
      if (existing.campaignId !== campaignId) {
        return refuse('attempt_id_conflict', { reservation: existing });
      }
      // The same attempt again: answer as before, change nothing.
      if (expiredRefund > 0) saveProgress(tx, ref, progress);
      const accepted = ['reserved', 'committed', 'settled'].includes(
        existing.status,
      );
      return {
        accepted,
        duplicate: true,
        auraChanged: auraChanged(),
        reason: accepted ? 'accepted' : 'reservation_refunded',
        reservation: existing,
        progress,
      };
    }

    const activeReservation = progress.entryReservations.find(
      isActiveReservation,
    );
    if (activeReservation) {
      return refuse('active_entry_conflict', {
        reservation: activeReservation,
      });
    }
    if (!_entryPrerequisitesMet(progress, event)) {
      return refuse('campaign_locked');
    }

    const amount = int(event.entryFee, { min: 0, max: MAX_ENTRY_FEE });
    const paid = amount <= 0 ? 0 : deductAup(progress, event.group, amount);
    if (paid < 0) return refuse('insufficient_funds');

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
    putReservation(progress, reservation);
    touchActivity(progress);
    saveProgress(tx, ref, progress);
    return {
      accepted: true,
      duplicate: false,
      auraChanged: auraChanged(),
      reason: amount <= 0 ? 'free_entry_reserved' : 'accepted',
      delta: -amount + expiredRefund,
      reservation,
      progress,
    };
  });
}

function _commit(reservation) {
  if (reservation.status === 'reserved') {
    reservation.status = 'committed';
    reservation.updatedAtMs = Date.now();
    return { accepted: true, duplicate: false, reason: 'accepted', delta: 0 };
  }
  if (reservation.status === 'committed' || reservation.status === 'settled') {
    return { accepted: true, duplicate: true, reason: 'accepted', delta: 0 };
  }
  return {
    accepted: false,
    duplicate: false,
    reason: 'reservation_refunded',
    delta: 0,
  };
}

function _refund(progress, reservation) {
  if (reservation.status === 'reserved') {
    const delta = addAup(progress, reservation.group, reservation.amount);
    reservation.status = 'refunded';
    reservation.updatedAtMs = Date.now();
    return { accepted: true, duplicate: false, reason: 'accepted', delta };
  }
  if (reservation.status === 'refunded') {
    return { accepted: true, duplicate: true, reason: 'accepted', delta: 0 };
  }
  return {
    accepted: false,
    duplicate: false,
    reason: reservation.status === 'settled'
      ? 'entry_already_settled'
      : 'entry_already_committed',
    delta: 0,
  };
}

// A started game that never reported a result, closed after a safety
// window in case it is still being played. It counts as leaving the table:
// last place, and the fee stays spent. Builds that promise a refund
// (rules version 1) get the fee back instead.
function _recover(progress, reservation, rulesVersion) {
  if (reservation.status === 'committed') {
    const ageMs = Date.now() - reservation.updatedAtMs;
    if (ageMs < ENTRY_RECOVERY_DELAY_MS) {
      return {
        accepted: false,
        duplicate: false,
        reason: 'recovery_not_ready',
        delta: 0,
      };
    }
    const seats = campaignEvent(
      reservation.campaignId,
      reservation.catalogVersion,
    )?.maxPlayers || 2;
    recordMatch(progress, {
      finishRank: seats,
      totalPlayers: seats,
      abandoned: true,
    });
    reservation.updatedAtMs = Date.now();
    if (rulesVersion >= 2) {
      reservation.status = 'settled';
      reservation.outcome = 'forfeited';
      return {
        accepted: true,
        duplicate: false,
        reason: 'abandoned_entry_forfeited',
        delta: 0,
      };
    }
    const refunded = addAup(progress, reservation.group, reservation.amount);
    reservation.status = 'refunded';
    return {
      accepted: true,
      duplicate: false,
      reason: 'abandoned_entry_recovered',
      delta: refunded,
    };
  }
  if (reservation.status === 'settled' && reservation.outcome === 'forfeited') {
    return {
      accepted: true,
      duplicate: true,
      reason: 'abandoned_entry_forfeited',
      delta: 0,
    };
  }
  if (reservation.status === 'refunded') {
    return {
      accepted: true,
      duplicate: true,
      reason: 'abandoned_entry_recovered',
      delta: 0,
    };
  }
  return {
    accepted: false,
    duplicate: false,
    reason: reservation.status === 'settled'
      ? 'entry_already_settled'
      : 'entry_not_committed',
    delta: 0,
  };
}

/**
 * transition: 'commit' | 'refund' | 'recover'. rulesVersion is what the
 * client asked for (constants.requestedRulesVersion).
 */
async function transitionEntryReservation({
  db,
  uid,
  body,
  transition,
  rulesVersion = ECONOMY_RULES_VERSION,
}) {
  return withWallet(db, uid, ({ tx, ref, progress, auraChanged }) => {
    const expiredRefund = reconcileExpiredReservations(progress);
    const attemptId = cleanId(body.attemptId);
    const reservation = attemptId ? findReservation(progress, attemptId) : null;
    if (!reservation) {
      if (expiredRefund > 0) saveProgress(tx, ref, progress);
      return {
        accepted: false,
        duplicate: false,
        reason: attemptId ? 'reservation_not_found' : 'attempt_id_required',
        progress,
      };
    }

    let outcome = {
      accepted: false,
      duplicate: false,
      reason: 'invalid_reservation_state',
      delta: 0,
    };
    if (transition === 'commit') outcome = _commit(reservation);
    if (transition === 'refund') outcome = _refund(progress, reservation);
    if (transition === 'recover') {
      outcome = _recover(progress, reservation, rulesVersion);
    }

    if (outcome.accepted || expiredRefund > 0) {
      saveProgress(tx, ref, progress);
    }
    return {
      accepted: outcome.accepted,
      duplicate: outcome.duplicate,
      auraChanged: auraChanged(),
      reason: outcome.reason,
      delta: expiredRefund + outcome.delta,
      reservation,
      progress,
    };
  });
}

/** Where an entry stands, for an app resuming after a crash or restart. */
async function entryReservationStatus({ db, uid, attemptId }) {
  return withWallet(db, uid, ({ tx, ref, progress, existed, auraChanged }) => {
    const refunded = reconcileExpiredReservations(progress);
    if (!existed || refunded > 0) saveProgress(tx, ref, progress);
    const normalizedAttemptId = cleanId(attemptId);
    const reservation = normalizedAttemptId
      ? findReservation(progress, normalizedAttemptId)
      : null;
    return {
      accepted: reservation != null,
      duplicate: false,
      auraChanged: auraChanged(),
      reason: reservation ? 'accepted' : 'reservation_not_found',
      reservation,
      progress,
    };
  });
}

module.exports = {
  entryReservationStatus,
  reserveEntry,
  transitionEntryReservation,
};
