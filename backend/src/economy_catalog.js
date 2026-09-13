const crypto = require('node:crypto');
const catalog = require('./economy_catalog.json');
const compatibilityCatalog494 = require('./economy_catalog_compat_494.json');
// The 550 catalog is the last one built before the circuits were redrawn
// (Australia -> Australasia, Central Asia -> Eurasia, Pacific -> Rest of
// the World). Clients already in the field compute their campaign ids and
// prizes from it, so it stays servable until those builds age out.
const compatibilityCatalog550 = require('./economy_catalog_compat_550.json');

const LEGACY_ECONOMY_CATALOG_VERSION =
  'v1:441:642c58b38694044f869bad6873e5c76df042c87e4abc8be3db29ebaea2e802fb';

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
const ECONOMY_CATALOG_494_VERSION = _validateCatalog(compatibilityCatalog494);
const ECONOMY_CATALOG_550_VERSION = _validateCatalog(compatibilityCatalog550);
const ECONOMY_CATALOG_CONTENT_HASH = catalog.contentHash;
// Deduplicated: until the catalog is rebuilt after a content change, the
// live version and the compatibility copy are the same string.
const SUPPORTED_ECONOMY_CATALOG_VERSIONS = Object.freeze([
  ...new Set([
    ECONOMY_CATALOG_VERSION,
    ECONOMY_CATALOG_550_VERSION,
    ECONOMY_CATALOG_494_VERSION,
    LEGACY_ECONOMY_CATALOG_VERSION,
  ]),
]);
const catalogsByVersion = new Map([
  [ECONOMY_CATALOG_VERSION, catalog],
  [ECONOMY_CATALOG_550_VERSION, compatibilityCatalog550],
  [ECONOMY_CATALOG_494_VERSION, compatibilityCatalog494],
  // The 441 release did not contain North America. Its common events are
  // compatible with the current non-North-America catalog entries.
  [LEGACY_ECONOMY_CATALOG_VERSION, catalog],
]);

function requestedCatalogVersion(raw) {
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    return LEGACY_ECONOMY_CATALOG_VERSION;
  }
  const requested = raw.trim();
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

function campaignEventCount(catalogVersion = ECONOMY_CATALOG_VERSION) {
  return (catalogsByVersion.get(catalogVersion) || catalog).eventCount;
}

module.exports = {
  ECONOMY_CATALOG_494_VERSION,
  ECONOMY_CATALOG_CONTENT_HASH,
  ECONOMY_CATALOG_VERSION,
  LEGACY_ECONOMY_CATALOG_VERSION,
  SUPPORTED_ECONOMY_CATALOG_VERSIONS,
  campaignEvent,
  campaignEventCount,
  requestedCatalogVersion,
};
