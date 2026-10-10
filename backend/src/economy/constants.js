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

// Granted once, spread across the circuits, to a registered player whose
// wallet is empty.
const REGISTERED_STARTER_AUP = 10000;

// Share of the whole wallet, in thousandths, lost for quitting a table or
// for finishing anywhere but first.
const QUIT_PENALTY_PERMILLE = 3;
const LOSS_PENALTY_PERMILLE = 1;

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
  ENTRY_RECOVERY_DELAY_MS,
  ENTRY_RESERVATION_TTL_MS,
  LOSS_PENALTY_PERMILLE,
  MAX_AUP_PER_CIRCUIT,
  MAX_CAMPAIGN_WIN_AUP,
  MAX_ENTRY_FEE,
  MAX_STORED_ENTRY_RESERVATIONS,
  MAX_TOTAL_AUP,
  MAX_TOTAL_AURA_MILLI,
  MIGRATION_COMPLETE_VERSION,
  QUIT_PENALTY_PERMILLE,
  REGISTERED_STARTER_AUP,
  normalizeCircuitAup,
};
