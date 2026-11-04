// Every number that sets the rules of the AUP economy, in one place.

const AUP_PER_AURA = 10000000;
const AURA_MILLI_PER_AURA = 1000;
const MAX_AURA_PER_CIRCUIT = 20;
const MAX_TOTAL_AURA = 100;

const MAX_AUP_PER_CIRCUIT = AUP_PER_AURA * MAX_AURA_PER_CIRCUIT;
const MAX_TOTAL_AUP = AUP_PER_AURA * MAX_TOTAL_AURA;
const MAX_TOTAL_AURA_MILLI = MAX_TOTAL_AURA * AURA_MILLI_PER_AURA;

// The client economy has a regression test proving that every configured
// fort and main-event reward fits under this per-event ceiling.
const MAX_CAMPAIGN_WIN_AUP = 25000000;
const MAX_ENTRY_FEE = 10000000;

// Granted once, spread evenly across the five circuits (400,000 each), to any
// account whose wallet is empty: registered players and guest (anonymous)
// accounts alike. Paid forts cost 52,000-376,000 (median about 100,000) and
// third place returns 1.5x the fee, so 400,000 a circuit is about three real
// attempts before the free forts are the way back. It was 10,000 in all
// (2,000 a circuit) until October 2026, which could not pay for a single
// paid fort. The name and its stored flag predate guests.
const REGISTERED_STARTER_AUP = 2000000;
const STARTER_AUP_PER_CIRCUIT = REGISTERED_STARTER_AUP / 5;
// Starter version 2 (October 2026): every circuit of every wallet holds at
// least STARTER_AUP_PER_CIRCUIT once, so players who started on the old
// 10,000 are topped up too. Applied once per wallet; never lowers a balance.
const STARTER_VERSION = 2;

// What a game can cost. The entry fee is the most a player can lose: a
// finish outside the prizes, leaving the table, and a game interrupted
// before it finished all cost the fee and nothing more. Quick Game is
// practice and never changes the wallet. (Until October 2026 every loss
// also took a share of the whole wallet; see docs/ECONOMY_RULES.md.)
//
// Clients send the rules they were built to explain in X-Economy-Rules.
//   1  no header: builds up to 86. An interrupted game is refunded, because
//      those builds tell the player the fee comes back.
//   2  build 87 on. An interrupted game is forfeited, like leaving.
const ECONOMY_RULES_VERSION = 2;
const LEGACY_ECONOMY_RULES_VERSION = 1;

/** The rules version a request asked for; missing or unknown means legacy. */
function requestedRulesVersion(raw) {
  const value = Number.parseInt(String(raw ?? '').trim(), 10);
  if (!Number.isInteger(value) || value < LEGACY_ECONOMY_RULES_VERSION) {
    return LEGACY_ECONOMY_RULES_VERSION;
  }
  return Math.min(value, ECONOMY_RULES_VERSION);
}

// An entry fee is held for an hour; an entry that never started is refunded
// after that. A started entry can be written off as abandoned after ten
// minutes without a result.
const ENTRY_RESERVATION_TTL_MS = 60 * 60 * 1000;
const ENTRY_RECOVERY_DELAY_MS = 10 * 60 * 1000;
const MAX_STORED_ENTRY_RESERVATIONS = 40;

// Clients refuse a wallet below this marker. Every wallet the server creates
// starts at it; older ones are brought up to it by
// scripts/migrate_legacy_wallets.js.
const MIGRATION_COMPLETE_VERSION = 1;

// Before North America existed, four circuits could each hold 25 Aura.
const FOUR_CIRCUIT_MAX_AUP_PER_CIRCUIT = AUP_PER_AURA * 25;
const FOUR_CIRCUIT_FIELDS = Object.freeze([
  'indiaAup',
  'internationalAup',
  'euroAup',
  'oceaniaAup',
]);

function _boundedInt(value, max) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return Math.min(Math.max(Math.trunc(value), 0), max);
}

// The five-circuit economy keeps the same 100-Aura lifetime ceiling by moving
// the old circuits' 20-25 Aura slices into North America. A wallet nobody has
// opened since then still holds the old shape, so this runs on every load.
// Capping inputs at their former limit stops malformed data from creating
// Aura, and makes the operation safe to repeat.
function normalizeCircuitAup(data = {}) {
  let overflowAup = 0;
  const normalized = {};
  for (const field of FOUR_CIRCUIT_FIELDS) {
    const value = _boundedInt(data[field], FOUR_CIRCUIT_MAX_AUP_PER_CIRCUIT);
    normalized[field] = Math.min(value, MAX_AUP_PER_CIRCUIT);
    overflowAup += Math.max(value - MAX_AUP_PER_CIRCUIT, 0);
  }
  const northAmericaAup = _boundedInt(
    data.northAmericaAup,
    MAX_AUP_PER_CIRCUIT,
  );
  normalized.northAmericaAup = Math.min(
    northAmericaAup + overflowAup,
    MAX_AUP_PER_CIRCUIT,
  );
  return normalized;
}

module.exports = {
  AUP_PER_AURA,
  AURA_MILLI_PER_AURA,
  ECONOMY_RULES_VERSION,
  ENTRY_RECOVERY_DELAY_MS,
  ENTRY_RESERVATION_TTL_MS,
  LEGACY_ECONOMY_RULES_VERSION,
  MAX_AUP_PER_CIRCUIT,
  MAX_CAMPAIGN_WIN_AUP,
  MAX_ENTRY_FEE,
  MAX_STORED_ENTRY_RESERVATIONS,
  MAX_TOTAL_AUP,
  MAX_TOTAL_AURA_MILLI,
  MIGRATION_COMPLETE_VERSION,
  REGISTERED_STARTER_AUP,
  STARTER_AUP_PER_CIRCUIT,
  STARTER_VERSION,
  normalizeCircuitAup,
  requestedRulesVersion,
};
