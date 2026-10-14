// The campaign catalog: every fort and title match, with its circuit, entry
// fee, table size and payouts. The server prices entries and pays results
// from this, never from what a client claims.
//
// catalog.json is generated from the app's own tables by
// tools/export_economy_catalog.dart; tools/verify_economy_catalog.sh fails a
// release if the two drift.
const crypto = require('node:crypto');

const catalog = require('./catalog.json');
// Build 82 (1.2.8, September 2026) prices its forts from the catalog made
// just before the circuits were redrawn (Australia -> Australasia, Central
// Asia -> Eurasia, Pacific -> Rest of the World).
const compatibilityCatalog550 = require('./catalog_compat_550.json');
// Builds 83-85 (1.2.8-1.2.10) price theirs from the catalog in which Eurasia
// held eleven kingdoms and Central Asia's forts were sk:euro:central_asia:*.
const compatibilityCatalog550Eurasia11 = require(
  './catalog_compat_550_eurasia11.json',
);
// Delete a compatibility catalog once Play Console shows no meaningful
// installs of the builds that use it. A build whose catalog is gone is told
// its economy is out of date and asked to update.

function _validateCatalog(candidate) {
  const calculatedContentHash = crypto
    .createHash('sha256')
    .update(JSON.stringify({
      schemaVersion: candidate?.schemaVersion,
      eventCount: candidate?.eventCount,
      events: candidate?.events,
    }))
    .digest('hex');
  const eventsHaveValidTableSizes =
    candidate?.events &&
    Object.values(candidate.events).every((event) =>
      Number.isInteger(event?.maxPlayers) &&
      event.maxPlayers >= 2 &&
      event.maxPlayers <= 10,
    );

  if (
    candidate?.schemaVersion !== 1 ||
    typeof candidate?.events !== 'object' ||
    candidate.events == null ||
    Object.keys(candidate.events).length !== candidate.eventCount ||
    typeof candidate.contentHash !== 'string' ||
    !/^[a-f0-9]{64}$/.test(candidate.contentHash) ||
    candidate.contentHash !== calculatedContentHash ||
    !eventsHaveValidTableSizes
  ) {
    throw new Error('A bundled economy catalog is invalid.');
  }

  return `v${candidate.schemaVersion}:${candidate.eventCount}:${candidate.contentHash}`;
}

const ECONOMY_CATALOG_VERSION = _validateCatalog(catalog);
const ECONOMY_CATALOG_550_VERSION = _validateCatalog(compatibilityCatalog550);
const ECONOMY_CATALOG_550_EURASIA11_VERSION = _validateCatalog(
  compatibilityCatalog550Eurasia11,
);
const ECONOMY_CATALOG_CONTENT_HASH = catalog.contentHash;

const catalogsByVersion = new Map([
  [ECONOMY_CATALOG_550_EURASIA11_VERSION, compatibilityCatalog550Eurasia11],
  [ECONOMY_CATALOG_550_VERSION, compatibilityCatalog550],
  // Last, so the live catalog wins if a compatibility copy is identical.
  [ECONOMY_CATALOG_VERSION, catalog],
]);
const SUPPORTED_ECONOMY_CATALOG_VERSIONS = Object.freeze([
  ECONOMY_CATALOG_VERSION,
  ...[...catalogsByVersion.keys()].filter(
    (version) => version !== ECONOMY_CATALOG_VERSION,
  ),
]);

/**
 * The catalog a request is priced against: the one its build declares in
 * X-Economy-Catalog-Version when the server still has it, otherwise the
 * live catalog. The response echoes the version back, so a build whose
 * catalog is gone sees the mismatch and asks the player to update.
 */
function requestedCatalogVersion(raw) {
  const requested = typeof raw === 'string' ? raw.trim() : '';
  return catalogsByVersion.has(requested)
    ? requested
    : ECONOMY_CATALOG_VERSION;
}

function campaignEvent(
  campaignId,
  catalogVersion = ECONOMY_CATALOG_VERSION,
) {
  if (typeof campaignId !== 'string') return null;
  const id = campaignId.trim();
  if (!id || id.length > 120) return null;
  const selectedCatalog = catalogsByVersion.get(catalogVersion) || catalog;
  const event = selectedCatalog.events[id];
  if (!event || event.id !== id) return null;
  return event;
}

/** Forts in the live journey (500): every catalog event that is not a title. */
const FORT_TOTAL = Object.values(catalog.events)
  .filter((event) => event.kind === 'fort').length;

// Live fort id by kingdom and fort number ("australia:3"). Redrawing the
// circuits moved three kingdoms (Australia, Central Asia, Pacific) to another
// circuit, which changed their ids (sk:<circuit>:<kingdom>:<n>) but not their
// forts: the same kingdom and number is the same fort.
const LIVE_FORT_BY_KINGDOM_NUMBER = new Map(
  Object.values(catalog.events)
    .filter((event) => event.kind === 'fort')
    .map((event) => [event.id.split(':').slice(2).join(':'), event.id]),
);

/** The live id of a fort cleared under any catalog the server knows, or null. */
function liveFortId(rawId) {
  if (typeof rawId !== 'string') return null;
  const id = rawId.trim();
  if (catalog.events[id]?.kind === 'fort') return id;
  for (const known of catalogsByVersion.values()) {
    if (known.events[id]?.kind === 'fort') {
      return LIVE_FORT_BY_KINGDOM_NUMBER.get(id.split(':').slice(2).join(':')) ||
        null;
    }
  }
  return null;
}

/**
 * How many different forts a list of cleared campaign ids names. A fort
 * cleared before its kingdom moved circuit still counts, and counts once
 * even if it was cleared again under its new id. Never more than FORT_TOTAL.
 */
function fortsClearedCount(clearedIds) {
  if (!Array.isArray(clearedIds)) return 0;
  const forts = new Set();
  for (const raw of clearedIds) {
    const id = liveFortId(raw);
    if (id) forts.add(id);
  }
  return Math.min(forts.size, FORT_TOTAL);
}

function campaignEventCount(catalogVersion = ECONOMY_CATALOG_VERSION) {
  return (catalogsByVersion.get(catalogVersion) || catalog).eventCount;
}

module.exports = {
  ECONOMY_CATALOG_550_EURASIA11_VERSION,
  ECONOMY_CATALOG_550_VERSION,
  ECONOMY_CATALOG_CONTENT_HASH,
  ECONOMY_CATALOG_VERSION,
  FORT_TOTAL,
  SUPPORTED_ECONOMY_CATALOG_VERSIONS,
  campaignEvent,
  campaignEventCount,
  fortsClearedCount,
  liveFortId,
  requestedCatalogVersion,
};
