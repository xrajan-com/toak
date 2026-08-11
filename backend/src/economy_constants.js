const AUP_PER_AURA = 10000000;
const AURA_MILLI_PER_AURA = 1000;
const MAX_AURA_PER_CIRCUIT = 20;
const MAX_TOTAL_AURA = 100;

const MAX_AUP_PER_CIRCUIT = AUP_PER_AURA * MAX_AURA_PER_CIRCUIT;
const MAX_TOTAL_AUP = AUP_PER_AURA * MAX_TOTAL_AURA;
const MAX_TOTAL_AURA_MILLI = MAX_TOTAL_AURA * AURA_MILLI_PER_AURA;
const LEGACY_MAX_AUP_PER_CIRCUIT = AUP_PER_AURA * 25;

const LEGACY_CIRCUIT_FIELDS = Object.freeze([
  'indiaAup',
  'internationalAup',
  'euroAup',
  'oceaniaAup',
]);

function _boundedInt(value, max) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return Math.min(Math.max(Math.trunc(value), 0), max);
}

// Before North America existed, four circuits could each hold 25 Aura. The
// five-circuit economy keeps the same 100-Aura lifetime ceiling by moving the
// old circuits' 20-25 Aura slices into North America. Capping legacy inputs at
// their former limit prevents malformed data from creating Aura during the
// migration, and makes the operation safe to repeat.
function normalizeCircuitAup(data = {}) {
  let overflowAup = 0;
  const normalized = {};
  for (const field of LEGACY_CIRCUIT_FIELDS) {
    const legacyValue = _boundedInt(data[field], LEGACY_MAX_AUP_PER_CIRCUIT);
    normalized[field] = Math.min(legacyValue, MAX_AUP_PER_CIRCUIT);
    overflowAup += Math.max(legacyValue - MAX_AUP_PER_CIRCUIT, 0);
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

// The client economy has a regression test proving that every configured
// fort and main-event reward fits under this per-event ceiling.
const MAX_CAMPAIGN_WIN_AUP = 25000000;
const MAX_ENTRY_FEE = 10000000;

module.exports = {
  AUP_PER_AURA,
  AURA_MILLI_PER_AURA,
  LEGACY_MAX_AUP_PER_CIRCUIT,
  MAX_AUP_PER_CIRCUIT,
  MAX_TOTAL_AUP,
  MAX_TOTAL_AURA_MILLI,
  MAX_CAMPAIGN_WIN_AUP,
  MAX_ENTRY_FEE,
  normalizeCircuitAup,
};
