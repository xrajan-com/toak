const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  LEGACY_MIGRATION_VERSION,
  mergeLegacyEconomy,
} = require('../src/legacy_economy_migration');

test('split legacy wallet and campaign documents merge field by field', () => {
  const result = mergeLegacyEconomy({
    walletData: {
      walletStorageVersion: 2,
      indiaAup: 45000,
      matchesPlayed: 3,
      registeredStarterGranted: true,
    },
    campaignData: {
      indiaAup: 1000,
      cleared: ['sk:india:test:1'],
      mainEventsCleared: ['me:india:test'],
      matchesPlayed: 5,
    },
  });

  assert.equal(result.data.indiaAup, 45000);
  assert.deepEqual(result.data.cleared, ['sk:india:test:1']);
  assert.deepEqual(result.data.mainEventsCleared, ['me:india:test']);
  assert.equal(result.data.matchesPlayed, 5);
  assert.equal(result.data.legacyMigrationVersion, LEGACY_MIGRATION_VERSION);
  assert.deepEqual(result.sources, ['campaign_progress', 'aura_wallets']);
  assert.equal(result.walletConflict, false);
});

test('an existing server wallet keeps its balance and gains missing clears', () => {
  const result = mergeLegacyEconomy({
    serverData: {
      walletVersion: 12,
      indiaAup: 90000,
      cleared: ['server-clear'],
      mainEventsCleared: [],
    },
    campaignData: {
      cleared: ['legacy-clear'],
      mainEventsCleared: ['legacy-title'],
    },
  });

  assert.equal(result.data.indiaAup, 90000);
  assert.deepEqual(result.data.cleared, ['server-clear', 'legacy-clear']);
  assert.deepEqual(result.data.mainEventsCleared, ['legacy-title']);
  assert.equal(result.walletConflict, false);
});

test('a pre-cutover empty starter document can recover a richer legacy wallet', () => {
  const result = mergeLegacyEconomy({
    serverData: {
      walletVersion: 1,
      indiaAup: 2000,
      internationalAup: 2000,
      euroAup: 2000,
      oceaniaAup: 2000,
      northAmericaAup: 2000,
      registeredStarterGranted: true,
    },
    campaignData: {
      indiaAup: 25000,
      registeredStarterGranted: true,
    },
  });

  assert.equal(result.data.indiaAup, 25000);
  assert.equal(result.recoveredFreshStarter, true);
  assert.equal(result.walletConflict, false);
});

test('a real authoritative wallet conflict is detected instead of overwritten', () => {
  const result = mergeLegacyEconomy({
    serverData: {
      walletVersion: 9,
      indiaAup: 30000,
      matchesPlayed: 2,
    },
    campaignData: { indiaAup: 40000 },
  });

  assert.equal(result.data.indiaAup, 30000);
  assert.equal(result.walletConflict, true);
});
