const LEGACY_MIGRATION_VERSION = 1;

const CIRCUIT_FIELDS = Object.freeze([
  'indiaAup',
  'internationalAup',
  'euroAup',
  'oceaniaAup',
  'northAmericaAup',
]);

const MONOTONIC_NUMBER_FIELDS = Object.freeze([
  'lastActiveAtMs',
  'prevActiveAtMs',
  'activityScore',
  'abandonedGames',
  'matchesPlayed',
  'finishPermilleSum',
]);

const MONOTONIC_LIST_FIELDS = Object.freeze([
  'awardedEventIds',
  'cleared',
  'mainEventsCleared',
]);

function _object(raw) {
  return raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
}

function _number(raw) {
  return typeof raw === 'number' && Number.isFinite(raw) ? raw : 0;
}

function _strings(...values) {
  const merged = new Set();
  for (const value of values) {
    if (!Array.isArray(value)) continue;
    for (const item of value) {
      if (typeof item === 'string' && item.length > 0) merged.add(item);
    }
  }
  return [...merged];
}

function _dedicatedWallet(data) {
  return [2, 3, 4].includes(_object(data).walletStorageVersion);
}

function _totalAup(data) {
  const source = _object(data);
  return CIRCUIT_FIELDS.reduce(
    (total, field) => total + Math.max(Math.trunc(_number(source[field])), 0),
    0,
  );
}

function _looksLikeFreshStarterServer(data) {
  const source = _object(data);
  const total = _totalAup(source);
  return (
    total <= 10000 &&
    _number(source.walletVersion) <= 1 &&
    _number(source.matchesPlayed) === 0 &&
    _strings(source.cleared).length === 0 &&
    _strings(source.mainEventsCleared).length === 0 &&
    (!Array.isArray(source.entryReservations) ||
      source.entryReservations.length === 0) &&
    (!Array.isArray(source.appliedEventIds) ||
      source.appliedEventIds.length === 0)
  );
}

/**
 * Merges the split legacy economy into a server-authoritative document.
 *
 * Wallet/stat fields come from the dedicated v2-v4 wallet when no server
 * document exists, otherwise from campaign_progress. Career fields are always
 * unioned because campaign completion is monotonic. Existing authoritative
 * wallets win unless they look exactly like the fresh 10k starter state that
 * the pre-migration backend created while ignoring a richer legacy wallet.
 */
function mergeLegacyEconomy({
  serverData,
  campaignData,
  walletData,
} = {}) {
  const server = _object(serverData);
  const campaign = _object(campaignData);
  const wallet = _object(walletData);
  const hasServer = Object.keys(server).length > 0;
  const hasCampaign = Object.keys(campaign).length > 0;
  const hasWallet = Object.keys(wallet).length > 0;
  const walletSource = _dedicatedWallet(wallet)
    ? wallet
    : (hasCampaign ? campaign : wallet);
  const sources = [
    ...(hasCampaign ? ['campaign_progress'] : []),
    ...(hasWallet ? ['aura_wallets'] : []),
  ];

  let merged = hasServer ? { ...server } : { ...walletSource };
  let recoveredFreshStarter = false;
  let walletConflict = false;

  if (hasServer && Object.keys(walletSource).length > 0) {
    const serverTotal = _totalAup(server);
    const legacyTotal = _totalAup(walletSource);
    if (serverTotal !== legacyTotal) {
      if (_looksLikeFreshStarterServer(server) && legacyTotal > serverTotal) {
        for (const field of CIRCUIT_FIELDS) merged[field] = walletSource[field];
        recoveredFreshStarter = true;
      } else if (legacyTotal > 0) {
        walletConflict = true;
      }
    }
  }

  for (const field of MONOTONIC_LIST_FIELDS) {
    merged[field] = _strings(server[field], campaign[field], wallet[field]);
  }
  for (const field of MONOTONIC_NUMBER_FIELDS) {
    merged[field] = Math.max(
      _number(server[field]),
      _number(campaign[field]),
      _number(wallet[field]),
    );
  }

  const activityCandidates = [
    server.lastActiveDayKey,
    campaign.lastActiveDayKey,
    wallet.lastActiveDayKey,
  ].filter((value) => typeof value === 'string');
  if (activityCandidates.length > 0) {
    merged.lastActiveDayKey = activityCandidates.sort().at(-1);
  }
  merged.registeredStarterGranted =
    server.registeredStarterGranted === true ||
    campaign.registeredStarterGranted === true ||
    wallet.registeredStarterGranted === true;
  merged.legacyMigrationVersion = LEGACY_MIGRATION_VERSION;
  merged.legacyMigrationSources = sources;

  return {
    data: merged,
    hasServer,
    sources,
    recoveredFreshStarter,
    walletConflict,
  };
}

module.exports = {
  CIRCUIT_FIELDS,
  LEGACY_MIGRATION_VERSION,
  mergeLegacyEconomy,
  _looksLikeFreshStarterServer,
  _totalAup,
};
