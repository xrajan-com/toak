// The daily tribute: AUP for coming back, once per local calendar day.
//
// The app sends the phone's UTC offset so that "a day" is the player's day,
// not London's. Claiming on the day after the last claim climbs the ladder
// (DAILY_TRIBUTE_LADDER); any longer gap starts again at day 1. The tribute
// is paid into the circuit of the player's latest fort entry, where AUP is
// actually being spent, or the first circuit before they have entered one.
const {
  DAILY_TRIBUTE_LADDER,
  DAILY_TRIBUTE_MIN_GAP_MS,
  MAX_TZ_OFFSET_MINUTES,
} = require('./constants');
const {
  addAup,
  clamp,
  dayKeyUtc,
  reconcileExpiredReservations,
} = require('./progress');
const { saveProgress, withWallet } = require('./store');

// The circuit a new player starts in (lib/config/venues.dart kVenueGroups).
const DEFAULT_TRIBUTE_CIRCUIT = 'india';
const DAY_MS = 24 * 60 * 60 * 1000;

/** The UTC offset in minutes the app sent, or 0 when it is not a real one. */
function tzOffsetMinutes(raw) {
  if (!Number.isInteger(raw)) return 0;
  if (Math.abs(raw) > MAX_TZ_OFFSET_MINUTES) return 0;
  return raw;
}

/** The player's calendar day (YYYY-MM-DD) at `nowMs`. */
function localDayKey(nowMs, offsetMinutes) {
  return dayKeyUtc(nowMs + offsetMinutes * 60 * 1000);
}

/** The day after a YYYY-MM-DD day. */
function nextDayKey(dayKey) {
  const ms = Date.parse(`${dayKey}T00:00:00Z`);
  if (!Number.isFinite(ms)) return '';
  return dayKeyUtc(ms + DAY_MS);
}

/** What claiming on day `streak` of a run pays (day 7 and on pay the top). */
function tributeAmount(streak) {
  const step = clamp(streak, 1, DAILY_TRIBUTE_LADDER.length);
  return DAILY_TRIBUTE_LADDER[step - 1];
}

/** The streak a claim on `today` would reach. */
function streakIfClaimed(progress, today) {
  if (
    progress.tributeStreak > 0 &&
    progress.tributeLastDayKey &&
    nextDayKey(progress.tributeLastDayKey) === today
  ) {
    return progress.tributeStreak + 1;
  }
  return 1;
}

/** The circuit of the latest fort entry, or the first circuit. */
function tributeCircuit(progress) {
  let latest = null;
  for (const reservation of progress.entryReservations) {
    if (!latest || reservation.createdAtMs >= latest.createdAtMs) {
      latest = reservation;
    }
  }
  return latest?.group || DEFAULT_TRIBUTE_CIRCUIT;
}

/**
 * Why a claim on `today` would be refused, or '' when it would be paid.
 * `already_claimed` is the usual answer to a retried request.
 */
function refusal(progress, today, nowMs) {
  const last = progress.tributeLastDayKey;
  if (last && today <= last) return 'already_claimed';
  if (
    progress.tributeLastClaimAtMs > 0 &&
    nowMs - progress.tributeLastClaimAtMs < DAILY_TRIBUTE_MIN_GAP_MS
  ) {
    return 'too_soon';
  }
  return '';
}

/**
 * Claims today's tribute for `uid`. Answers with the change, the streak it
 * reached and the circuit paid; a refused claim changes nothing and says why.
 */
async function claimDailyTribute({ db, uid, body = {}, nowMs = Date.now() }) {
  const offset = tzOffsetMinutes(body.tzOffsetMinutes);
  const today = localDayKey(nowMs, offset);
  return withWallet(db, uid, ({ tx, ref, progress, existed, starterGranted }) => {
    const refunded = reconcileExpiredReservations(progress, nowMs);
    const reason = refusal(progress, today, nowMs);
    if (reason) {
      if (!existed || starterGranted || refunded > 0) {
        saveProgress(tx, ref, progress);
      }
      return {
        accepted: false,
        duplicate: reason === 'already_claimed',
        reason,
        delta: 0,
        streak: progress.tributeStreak,
        group: '',
        auraChanged: false,
        progress,
      };
    }

    const streak = streakIfClaimed(progress, today);
    const group = tributeCircuit(progress);
    const delta = addAup(progress, group, tributeAmount(streak));
    progress.tributeStreak = streak;
    progress.tributeLastDayKey = today;
    progress.tributeLastClaimAtMs = nowMs;
    progress.tributeLastAmount = delta;
    progress.tributeClaims += 1;
    saveProgress(tx, ref, progress);
    return {
      accepted: true,
      duplicate: false,
      reason: '',
      delta,
      streak,
      group,
      auraChanged: delta !== 0,
      progress,
    };
  });
}

module.exports = {
  DEFAULT_TRIBUTE_CIRCUIT,
  claimDailyTribute,
  localDayKey,
  nextDayKey,
  streakIfClaimed,
  tributeAmount,
  tributeCircuit,
  tzOffsetMinutes,
};
