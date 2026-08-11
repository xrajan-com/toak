#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const localCatalog = require('../backend/src/economy_catalog.json');
const DEFAULT_FIREBASE_WEB_API_KEY = 'AIzaSyBDxo0Cz8BH8jomP0zsmkl9UBLDC2SS8L4';
const EXPECTED_CATALOG_EVENT_COUNT = localCatalog.eventCount;
const EXPECTED_CATALOG_CONTENT_HASH = localCatalog.contentHash;
const EXPECTED_CATALOG_VERSION =
  `v${localCatalog.schemaVersion}:${localCatalog.eventCount}:` +
  localCatalog.contentHash;

const apiBaseUrl = (process.env.API_BASE_URL || '').replace(/\/+$/, '');
const apiKey = process.env.FIREBASE_WEB_API_KEY || DEFAULT_FIREBASE_WEB_API_KEY;
const healthOnly = process.argv.includes('--health-only');
const ephemeralUser = process.argv.includes('--ephemeral-user');
const allowMutatingSmoke = process.env.ALLOW_MUTATING_SMOKE === '1';
let ephemeralIdentity = null;

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function totalAup(progress) {
  return [
    'indiaAup',
    'internationalAup',
    'euroAup',
    'oceaniaAup',
    'northAmericaAup',
  ]
    .reduce((sum, field) => sum + (Number(progress?.[field]) || 0), 0);
}

async function readJson(response) {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
}

async function request(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      accept: 'application/json',
      'x-economy-catalog-version': EXPECTED_CATALOG_VERSION,
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(
      `${method} ${path} failed with ${response.status}: ${JSON.stringify(data)}`,
    );
  }
  return data;
}

async function signInWithPassword() {
  const email = process.env.FIREBASE_TEST_EMAIL;
  const password = process.env.FIREBASE_TEST_PASSWORD;
  if (!email || !password) return '';

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    },
  );
  const data = await readJson(response);
  if (!response.ok || typeof data.idToken !== 'string') {
    throw new Error(`Firebase test sign-in failed: ${JSON.stringify(data)}`);
  }
  return data.idToken;
}

async function signUpEphemeralUser() {
  const nonce = crypto.randomBytes(18).toString('hex');
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: `backend-smoke-${nonce}@example.invalid`,
        password: `${nonce}Aa1!`,
        returnSecureToken: true,
      }),
    },
  );
  const data = await readJson(response);
  if (
    !response.ok ||
    typeof data.idToken !== 'string' ||
    typeof data.localId !== 'string'
  ) {
    throw new Error(`Ephemeral Firebase sign-up failed: ${JSON.stringify(data)}`);
  }
  ephemeralIdentity = { token: data.idToken, uid: data.localId };
  return data.idToken;
}

async function idToken() {
  if (process.env.FIREBASE_ID_TOKEN) return process.env.FIREBASE_ID_TOKEN;
  if (ephemeralUser) return signUpEphemeralUser();
  return signInWithPassword();
}

async function cleanUpEphemeralUser() {
  if (!ephemeralIdentity) return;
  const { token, uid } = ephemeralIdentity;
  const deleted = await request('/v1/auth/account', {
    method: 'DELETE',
    token,
    body: { confirmation: 'DELETE' },
  });
  if (deleted.deleted !== true) {
    throw new Error('Ephemeral smoke account cleanup was not confirmed.');
  }

  // Account deletion intentionally leaves a durable tombstone. This UID no
  // longer exists in Firebase Auth, so remove only that final smoke artifact.
  const oauthToken = execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
  }).trim();
  const projectId = process.env.FIREBASE_PROJECT_ID || 'ten-of-a-kind-poker';
  const tombstoneUrl =
    `https://firestore.googleapis.com/v1/projects/${projectId}/` +
    `databases/(default)/documents/account_deletions/${encodeURIComponent(uid)}`;
  const response = await fetch(tombstoneUrl, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${oauthToken}` },
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(
      `Ephemeral tombstone cleanup failed with ${response.status}.`,
    );
  }
  ephemeralIdentity = null;
  console.log('ephemeral smoke account cleaned up');
}

async function main() {
  if (!apiBaseUrl || !apiBaseUrl.startsWith('https://')) {
    throw new Error('Set API_BASE_URL to the HTTPS backend release URL.');
  }
  const health = await request('/health');
  if (health.ok !== true) {
    throw new Error(`Backend health is not ready: ${JSON.stringify(health)}`);
  }
  if (
    health.catalogVersion !== EXPECTED_CATALOG_VERSION ||
    health.catalogContentHash !== EXPECTED_CATALOG_CONTENT_HASH ||
    health.catalogEventCount !== EXPECTED_CATALOG_EVENT_COUNT
  ) {
    throw new Error(
      `Economy catalog mismatch: expected ${EXPECTED_CATALOG_VERSION} ` +
      `(${EXPECTED_CATALOG_EVENT_COUNT}), got ${health.catalogVersion} ` +
      `(${health.catalogEventCount})`,
    );
  }
  console.log(`health ok: ${health.service || 'backend'} ${health.ok === true ? 'ok' : ''}`.trim());

  if (healthOnly) return;

  const token = await idToken();
  if (!token) {
    fail(
      'Set FIREBASE_ID_TOKEN, or FIREBASE_TEST_EMAIL and FIREBASE_TEST_PASSWORD, to run authenticated smoke tests.',
    );
    return;
  }

  const wallet = await request('/v1/economy/wallet', { token });
  if ((Number(wallet.progress?.legacyMigrationVersion) || 0) < 1) {
    throw new Error(
      'wallet is not marked as having completed the production migration',
    );
  }
  console.log(`wallet ok: totalAup=${totalAup(wallet.progress)}`);

  if (!allowMutatingSmoke) {
    console.log('authenticated read-only smoke passed');
    return;
  }

  const stamp = Date.now();
  const campaignId = 'sk:international:central_asia:10';
  const totalPlayers = localCatalog.events[campaignId]?.maxPlayers;
  if (!Number.isInteger(totalPlayers)) {
    throw new Error(`local catalog is missing maxPlayers for ${campaignId}`);
  }
  const attemptId = `smoke:entry:${stamp}`;
  const reservation = await request('/v1/economy/entries/reserve', {
    method: 'POST',
    token,
    body: {
      campaignId,
      attemptId,
    },
  });
  if (
    reservation.accepted !== true ||
    reservation.reservation?.amount !== 0 ||
    reservation.reservation?.campaignId !== campaignId
  ) {
    throw new Error(`free entry reservation failed: ${JSON.stringify(reservation)}`);
  }
  console.log('catalog free-entry reservation ok');

  const committed = await request('/v1/economy/entries/commit', {
    method: 'POST',
    token,
    body: { attemptId },
  });
  if (
    committed.accepted !== true ||
    committed.reservation?.status !== 'committed'
  ) {
    throw new Error(`entry commit failed: ${JSON.stringify(committed)}`);
  }
  console.log('entry commit ok');

  const resultEventId = `smoke:campaign_result:${stamp}`;
  const campaignResult = await request('/v1/economy/events', {
    method: 'POST',
    token,
    body: {
      action: 'campaign_result',
      campaignId,
      entryAttemptId: attemptId,
      placement: 1,
      totalPlayers,
      eventId: resultEventId,
    },
  });
  if (
    campaignResult.accepted !== true ||
    campaignResult.clearRecorded !== true
  ) {
    throw new Error(`campaign result failed: ${JSON.stringify(campaignResult)}`);
  }
  console.log(`campaign result ok: payoutDelta=${campaignResult.payoutDelta}`);

  const duplicate = await request('/v1/economy/events', {
    method: 'POST',
    token,
    body: {
      action: 'campaign_result',
      campaignId,
      entryAttemptId: attemptId,
      placement: 1,
      totalPlayers,
      eventId: resultEventId,
    },
  });
  if (duplicate.duplicate !== true || duplicate.delta !== 0) {
    throw new Error(`duplicate replay failed: ${JSON.stringify(duplicate)}`);
  }
  console.log('duplicate result receipt ok: duplicate=true delta=0');

  const after = await request('/v1/economy/wallet', { token });
  if (!after.progress?.cleared?.includes(campaignId)) {
    throw new Error('wallet did not reflect the authoritative campaign clear');
  }
  if (totalAup(after.progress) < totalAup(wallet.progress)) {
    throw new Error('wallet total unexpectedly decreased after a first-place result');
  }
  console.log(`wallet reconciliation ok: totalAup=${totalAup(after.progress)}`);

  // Exercise the production paid-entry path after the free-fort payout. Forts
  // are sequence-independent; this one costs less than the resulting wallet.
  const paidCampaignId = 'sk:international:central_asia:3';
  const paidEvent = localCatalog.events[paidCampaignId];
  if (
    !paidEvent ||
    paidEvent.kind !== 'fort' ||
    paidEvent.group !== 'international' ||
    paidEvent.predecessorId != null ||
    !Number.isInteger(paidEvent.entryFee) ||
    paidEvent.entryFee <= 0
  ) {
    throw new Error(`invalid paid smoke catalog event: ${paidCampaignId}`);
  }
  const paidAttemptId = `smoke:paid_entry:${stamp}`;
  const paidReservation = await request('/v1/economy/entries/reserve', {
    method: 'POST',
    token,
    body: {
      campaignId: paidCampaignId,
      attemptId: paidAttemptId,
    },
  });
  if (
    paidReservation.accepted !== true ||
    paidReservation.reservation?.amount !== paidEvent.entryFee ||
    paidReservation.delta !== -paidEvent.entryFee
  ) {
    throw new Error(`paid entry reservation failed: ${JSON.stringify(paidReservation)}`);
  }
  const afterPaidReservation = await request('/v1/economy/wallet', { token });
  if (
    totalAup(afterPaidReservation.progress) !==
      totalAup(after.progress) - paidEvent.entryFee
  ) {
    throw new Error('paid entry fee was not deducted from the authoritative wallet');
  }
  console.log(`paid entry deduction ok: entryFee=${paidEvent.entryFee}`);

  const paidCommitted = await request('/v1/economy/entries/commit', {
    method: 'POST',
    token,
    body: { attemptId: paidAttemptId },
  });
  if (
    paidCommitted.accepted !== true ||
    paidCommitted.reservation?.status !== 'committed'
  ) {
    throw new Error(`paid entry commit failed: ${JSON.stringify(paidCommitted)}`);
  }

  const paidLoss = await request('/v1/economy/events', {
    method: 'POST',
    token,
    body: {
      action: 'campaign_result',
      campaignId: paidCampaignId,
      entryAttemptId: paidAttemptId,
      placement: paidEvent.maxPlayers,
      totalPlayers: paidEvent.maxPlayers,
      eventId: `smoke:paid_loss:${stamp}`,
    },
  });
  if (paidLoss.accepted !== true || paidLoss.clearRecorded === true) {
    throw new Error(`paid loss settlement failed: ${JSON.stringify(paidLoss)}`);
  }

  const afterPaidLoss = await request('/v1/economy/wallet', { token });
  const rejectedPaidAttempt = await request('/v1/economy/entries/reserve', {
    method: 'POST',
    token,
    body: {
      campaignId: paidCampaignId,
      attemptId: `smoke:unaffordable_entry:${stamp}`,
    },
  });
  if (
    rejectedPaidAttempt.accepted !== false ||
    rejectedPaidAttempt.reason !== 'insufficient_funds'
  ) {
    throw new Error(
      `unaffordable paid entry was not rejected: ${JSON.stringify(rejectedPaidAttempt)}`,
    );
  }
  const afterRejectedEntry = await request('/v1/economy/wallet', { token });
  if (totalAup(afterRejectedEntry.progress) !== totalAup(afterPaidLoss.progress)) {
    throw new Error('rejected paid entry unexpectedly changed the wallet');
  }
  console.log('paid entry affordability gate ok: insufficient funds rejected');

  // This server-authoritative sync also performs the bounded migration/prune
  // that replaces any legacy raw-UID leaderboard document ids with opaque ids.
  // Keep it in the required deploy smoke so privacy migration is not deferred
  // until an arbitrary production user next opens the leaderboard.
  const leaderboard = await request('/v1/leaderboard/sync', {
    method: 'POST',
    token,
    body: {},
  });
  if (
    typeof leaderboard.synced !== 'boolean' ||
    typeof leaderboard.removed !== 'boolean'
  ) {
    throw new Error(
      `leaderboard sync returned an invalid response: ${JSON.stringify(leaderboard)}`,
    );
  }
  console.log('leaderboard opaque-id migration and prune ok');
}

main()
  .then(cleanUpEphemeralUser)
  .catch(async (error) => {
    let cleanupError = null;
    try {
      await cleanUpEphemeralUser();
    } catch (caught) {
      cleanupError = caught;
    }
    fail(error?.message || String(error));
    if (cleanupError) {
      fail(`Smoke cleanup failed: ${cleanupError?.message || cleanupError}`);
    }
  });
