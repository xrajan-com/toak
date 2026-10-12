// Results reported by the app after a game, and other one-off events.
// Every event carries a client-chosen eventId; a receipt per eventId makes a
// retried request a harmless duplicate.
//
// Under the accepted trust model (docs/GAMEPLAY_TRUST_MODEL.md) the client
// reports where it finished. The server decides everything that follows
// from that: which circuit is paid, how much, and whether the entry was paid
// for. Prices and payouts come from the catalog, never from the request.
const { FieldValue } = require('firebase-admin/firestore');

const {
  ECONOMY_CATALOG_VERSION,
  campaignEvent,
} = require('./catalog');
const { MAX_CAMPAIGN_WIN_AUP } = require('./constants');
const {
  addAup,
  cleanId,
  findReservation,
  int,
  receiptId,
  reconcileExpiredReservations,
  recordAward,
  recordCampaignClear,
  recordMatch,
  settleReservation,
  touchActivity,
} = require('./progress');
const {
  ECONOMY_RECEIPTS_COLLECTION,
  saveProgress,
  withWallet,
} = require('./store');

const CAMPAIGN_ACTIONS = new Set([
  'campaign_win',
  'campaign_result',
  'campaign_abandoned',
]);

function _rejected(reason, progress) {
  return { accepted: false, duplicate: false, delta: 0, reason, progress };
}

/**
 * A fort or title-match result, settled against the paid entry it belongs
 * to. Returns the change to apply, or { reason } when it is refused.
 *
 * The entry fee was spent when the game started, so a result only ever
 * adds: the prize for the place, if the place pays. Losing or leaving
 * costs nothing beyond the fee.
 */
function _settleCampaign(progress, body, action, catalogVersion) {
  const isAbandoned = action === 'campaign_abandoned';
  const isFinalResult = action !== 'campaign_win';
  const campaignId = cleanId(body.campaignId);
  const attemptId = cleanId(body.entryAttemptId);
  const reservation = attemptId ? findReservation(progress, attemptId) : null;
  // An entry is always settled against the catalog it was bought under.
  const event = campaignEvent(
    campaignId,
    reservation?.catalogVersion || catalogVersion,
  );
  const totalPlayers = event?.maxPlayers ?? 0;
  const totalPlayersValid = body.totalPlayers == null ||
    (Number.isInteger(body.totalPlayers) &&
      body.totalPlayers === totalPlayers);
  const placement = isAbandoned
    ? totalPlayers
    : int(body.placement, { min: 1, max: totalPlayers });
  const placementValid = isAbandoned
    ? body.placement == null || body.placement === totalPlayers
    : Number.isInteger(body.placement) &&
      body.placement >= 1 &&
      body.placement <= totalPlayers;
  const payout = !isAbandoned && event && Array.isArray(event.payouts)
    ? int(event.payouts[placement - 1], { min: 0, max: MAX_CAMPAIGN_WIN_AUP })
    : 0;

  if (!event) return { reason: 'invalid_campaign_event', campaignId };
  if (!totalPlayersValid) return { reason: 'invalid_total_players', campaignId };
  if (!placementValid) return { reason: 'invalid_placement', campaignId };
  if (!isFinalResult && payout <= 0) {
    return { reason: 'invalid_placement', campaignId };
  }
  const paidEntry = reservation != null &&
    reservation.campaignId === event.id &&
    reservation.group === event.group;
  if (!paidEntry) return { reason: 'committed_entry_required', campaignId };
  if (!['committed', 'settled'].includes(reservation.status)) {
    return { reason: 'entry_not_committed', campaignId };
  }

  const won = !isAbandoned && placement === 1;
  if (reservation.status === 'settled') {
    // Already paid under another eventId: acknowledge, pay nothing.
    return {
      accepted: true,
      reason: 'duplicate_settlement',
      campaignId,
      clearRecorded: won && (event.kind === 'main'
        ? progress.mainEventsCleared.includes(event.id)
        : progress.cleared.includes(event.id)),
    };
  }

  let matchRecorded = false;
  if (isFinalResult) {
    recordMatch(progress, {
      finishRank: placement,
      totalPlayers,
      abandoned: isAbandoned,
    });
    matchRecorded = true;
  }
  const payoutDelta = addAup(progress, event.group, payout);
  if (won) recordCampaignClear(progress, event);
  if (!isAbandoned) recordAward(progress, campaignId);
  reservation.status = 'settled';
  reservation.updatedAtMs = Date.now();
  return {
    accepted: true,
    reason: payout > 0 && payoutDelta === 0 ? 'wallet_cap_reached' : 'accepted',
    campaignId,
    delta: payoutDelta,
    payoutDelta,
    // Kept in the response for builds that read it; always 0 now.
    penaltyDelta: 0,
    clearRecorded: won,
    matchRecorded,
  };
}

// Quick Game is practice: it counts towards the player's stats and never
// changes the wallet.
function _completeMatch(progress, body) {
  const totalPlayers = int(body.totalPlayers, { min: 1, max: 10 });
  const finishRank = int(body.finishRank, { min: 1, max: totalPlayers });
  recordMatch(progress, { finishRank, totalPlayers });
  settleReservation(progress, body.entryAttemptId);
  return { accepted: true, reason: 'accepted', delta: 0 };
}

function _abandonMatch(progress, body) {
  const totalPlayers = int(body.totalPlayers, { min: 1, max: 10 });
  recordMatch(progress, {
    finishRank: totalPlayers,
    totalPlayers,
    abandoned: true,
  });
  settleReservation(progress, body.entryAttemptId);
  return { accepted: true, reason: 'accepted', delta: 0 };
}

async function applyEconomyEvent({
  db,
  uid,
  body,
  catalogVersion = ECONOMY_CATALOG_VERSION,
}) {
  return withWallet(db, uid, async ({ tx, ref, progress, auraChanged }) => {
    const action = typeof body.action === 'string' ? body.action : '';
    const eventId = cleanId(body.eventId);
    if (!eventId) return _rejected('event_id_required', progress);

    const receiptRef = db
      .collection(ECONOMY_RECEIPTS_COLLECTION)
      .doc(receiptId(uid, eventId));
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

    reconcileExpiredReservations(progress);
    let outcome;
    if (action === 'rewarded_ad') {
      // Never trust a client's word that an ad was watched. Credits stay off
      // until a server-verified ad-provider callback exists.
      outcome = { reason: 'rewarded_ad_verification_required' };
    } else if (action === 'entry_fee') {
      // Retired: entries are paid through /entries/reserve at catalog price.
      return _rejected('entry_reservation_required', progress);
    } else if (CAMPAIGN_ACTIONS.has(action)) {
      outcome = _settleCampaign(progress, body, action, catalogVersion);
    } else if (action === 'match_completed') {
      outcome = _completeMatch(progress, body);
    } else if (action === 'game_abandoned') {
      outcome = _abandonMatch(progress, body);
    } else {
      outcome = { reason: 'unsupported_action' };
    }
    if (outcome.accepted !== true) return _rejected(outcome.reason, progress);

    const result = {
      delta: 0,
      payoutDelta: 0,
      penaltyDelta: 0,
      clearRecorded: false,
      matchRecorded: false,
      campaignId: '',
      ...outcome,
    };
    progress.appliedEventIds.push(eventId);
    progress.appliedEventIds = progress.appliedEventIds.slice(-500);
    touchActivity(progress);
    saveProgress(tx, ref, progress);
    tx.set(receiptRef, {
      uid,
      eventId,
      action,
      campaignId: result.campaignId,
      accepted: true,
      reason: result.reason,
      delta: result.delta,
      payoutDelta: result.payoutDelta,
      penaltyDelta: result.penaltyDelta,
      clearRecorded: result.clearRecorded,
      matchRecorded: result.matchRecorded,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      accepted: true,
      duplicate: false,
      auraChanged: auraChanged(),
      delta: result.delta,
      payoutDelta: result.payoutDelta,
      penaltyDelta: result.penaltyDelta,
      clearRecorded: result.clearRecorded,
      matchRecorded: result.matchRecorded,
      reason: result.reason,
      progress,
    };
  });
}

module.exports = { applyEconomyEvent };
