#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';

const backendRequire = createRequire(
  new URL('../backend/package.json', import.meta.url),
);
const {
  LEGACY_MIGRATION_VERSION,
  mergeLegacyEconomy,
} = backendRequire('./src/legacy_economy_migration');
const { _baseProgress } = backendRequire('./src/routes/economy');

const args = new Map(
  process.argv.slice(2).map((arg) => {
    const [key, ...rest] = arg.split('=');
    return [key, rest.length > 0 ? rest.join('=') : true];
  }),
);
const apply = args.has('--apply');
const projectId = String(
  args.get('--project') || process.env.FIREBASE_PROJECT_ID || '',
).trim();
const confirmedProject = String(args.get('--confirm-project') || '').trim();
const backupUri = String(args.get('--backup-uri') || '').trim();
const concurrency = Math.max(
  1,
  Math.min(Number(args.get('--concurrency') || 8), 20),
);
const databaseRoot =
  `projects/${projectId}/databases/(default)`;
const documentsRoot = `${databaseRoot}/documents`;
const apiRoot = `https://firestore.googleapis.com/v1/${databaseRoot}`;

function usage(message) {
  if (message) console.error(`ERROR: ${message}`);
  console.error(
    'Usage: node tools/migrate_legacy_economy.mjs --project=PROJECT ' +
    '[--apply --confirm-project=PROJECT --backup-uri=gs://BUCKET/PREFIX]',
  );
  process.exit(2);
}

if (!projectId) usage('--project is required.');
if (apply && confirmedProject !== projectId) {
  usage('--confirm-project must exactly match --project for --apply.');
}
if (apply && !/^gs:\/\/[a-z0-9._-]+\/.+/.test(backupUri)) {
  usage('--backup-uri must identify the completed pre-migration export.');
}

let accessToken = '';
function refreshOauthToken() {
  const supplied = String(process.env.GOOGLE_OAUTH_ACCESS_TOKEN || '').trim();
  accessToken = supplied || execFileSync(
    'gcloud',
    ['auth', 'print-access-token'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] },
  ).trim();
}
refreshOauthToken();

async function api(path, {
  method = 'GET',
  body,
  allowNotFound = false,
  retryAuth = true,
} = {}) {
  const response = await fetch(`${apiRoot}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: 'application/json',
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (response.status === 401 && retryAuth) {
    refreshOauthToken();
    return api(path, { method, body, allowNotFound, retryAuth: false });
  }
  if (allowNotFound && response.status === 404) return null;
  const text = await response.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { raw: text.slice(0, 1000) };
    }
  }
  if (!response.ok) {
    const error = new Error(
      `${method} ${path} failed (${response.status}): ${JSON.stringify(data)}`,
    );
    error.status = response.status;
    throw error;
  }
  return data;
}

function decodeValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue === true;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('timestampValue' in value) return value.timestampValue;
  if ('stringValue' in value) return value.stringValue;
  if ('bytesValue' in value) return value.bytesValue;
  if ('referenceValue' in value) return value.referenceValue;
  if ('geoPointValue' in value) return value.geoPointValue;
  if ('arrayValue' in value) {
    return (value.arrayValue?.values || []).map(decodeValue);
  }
  if ('mapValue' in value) return decodeFields(value.mapValue?.fields || {});
  return null;
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields || {}).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function encodeValue(value) {
  if (value == null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('Cannot encode non-finite number.');
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value) } };
  }
  throw new Error(`Unsupported Firestore value: ${typeof value}`);
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function documentId(name) {
  return decodeURIComponent(name.slice(name.lastIndexOf('/') + 1));
}

function decodedDocument(document) {
  if (!document) return null;
  return {
    id: documentId(document.name),
    data: decodeFields(document.fields || {}),
    updateTime: document.updateTime,
  };
}

async function listCollection(collection) {
  const documents = [];
  let pageToken = '';
  do {
    const query = new URLSearchParams({ pageSize: '1000' });
    if (pageToken) query.set('pageToken', pageToken);
    const page = await api(`/documents/${collection}?${query}`);
    documents.push(...(page.documents || []).map(decodedDocument));
    pageToken = page.nextPageToken || '';
  } while (pageToken);
  return new Map(documents.map((doc) => [doc.id, doc]));
}

function stringSet(raw) {
  return new Set(
    Array.isArray(raw) ? raw.filter((value) => typeof value === 'string') : [],
  );
}

function containsAll(container, required) {
  const values = stringSet(container);
  return [...stringSet(required)].every((value) => values.has(value));
}

function normalizedJson(data) {
  return JSON.stringify(_baseProgress(data));
}

function planOne({ serverData, campaignData, walletData }) {
  if (
    serverData &&
    Number(serverData.legacyMigrationVersion) >= LEGACY_MIGRATION_VERSION
  ) {
    const normalized = _baseProgress(serverData);
    if (
      !containsAll(normalized.cleared, campaignData?.cleared) ||
      !containsAll(
        normalized.mainEventsCleared,
        campaignData?.mainEventsCleared,
      )
    ) {
      throw new Error(
        'A completed migration marker exists without all campaign clears.',
      );
    }
    return {
      merged: {
        sources: normalized.legacyMigrationSources,
        recoveredFreshStarter: false,
        walletConflict: false,
      },
      normalized,
      needsWrite: false,
    };
  }

  const merged = mergeLegacyEconomy({
    serverData,
    campaignData,
    walletData,
  });
  const normalized = _baseProgress(merged.data);
  const existingNormalized = serverData ? _baseProgress(serverData) : null;
  const needsWrite = !existingNormalized ||
    existingNormalized.legacyMigrationVersion < LEGACY_MIGRATION_VERSION ||
    normalizedJson(existingNormalized) !== normalizedJson(normalized);

  if (!containsAll(normalized.cleared, campaignData?.cleared)) {
    throw new Error('Migration invariant failed: campaign clear would be lost.');
  }
  if (!containsAll(
    normalized.mainEventsCleared,
    campaignData?.mainEventsCleared,
  )) {
    throw new Error('Migration invariant failed: campaign title would be lost.');
  }
  return { merged, normalized, needsWrite };
}

async function readState() {
  const [server, campaign, wallet, deletions] = await Promise.all([
    listCollection('server_progress'),
    listCollection('campaign_progress'),
    listCollection('aura_wallets'),
    listCollection('account_deletions'),
  ]);
  return { server, campaign, wallet, deleted: new Set(deletions.keys()) };
}

function buildPlan(state) {
  const ids = new Set([
    ...state.server.keys(),
    ...state.campaign.keys(),
    ...state.wallet.keys(),
  ]);
  const summary = {
    candidates: ids.size,
    deletedSkipped: 0,
    unchanged: 0,
    creates: 0,
    updates: 0,
    freshStarterRecoveries: 0,
    walletConflicts: 0,
  };
  const writes = [];

  for (const id of ids) {
    if (state.deleted.has(id)) {
      summary.deletedSkipped += 1;
      continue;
    }
    const server = state.server.get(id);
    const planned = planOne({
      serverData: server?.data,
      campaignData: state.campaign.get(id)?.data,
      walletData: state.wallet.get(id)?.data,
    });
    if (planned.merged.walletConflict) summary.walletConflicts += 1;
    if (planned.merged.recoveredFreshStarter) {
      summary.freshStarterRecoveries += 1;
    }
    if (!planned.needsWrite) {
      summary.unchanged += 1;
      continue;
    }
    if (server) summary.updates += 1;
    else summary.creates += 1;
    writes.push(id);
  }
  return { summary, writes };
}

function docPath(collection, id) {
  return `${documentsRoot}/${collection}/${encodeURIComponent(id)}`;
}

async function getInTransaction(collection, id, transaction) {
  const path = `/documents/${collection}/${encodeURIComponent(id)}`;
  const query = new URLSearchParams({ transaction });
  return decodedDocument(await api(`${path}?${query}`, {
    allowNotFound: true,
  }));
}

async function rollback(transaction) {
  await api('/documents:rollback', {
    method: 'POST',
    body: { transaction },
  });
}

async function migrateOne(id, attempt = 1) {
  const { transaction } = await api('/documents:beginTransaction', {
    method: 'POST',
    body: { options: { readWrite: {} } },
  });
  try {
    const deletion = await getInTransaction('account_deletions', id, transaction);
    const server = await getInTransaction('server_progress', id, transaction);
    const campaign = await getInTransaction('campaign_progress', id, transaction);
    const wallet = await getInTransaction('aura_wallets', id, transaction);
    if (deletion) {
      await rollback(transaction);
      return 'deleted';
    }
    const planned = planOne({
      serverData: server?.data,
      campaignData: campaign?.data,
      walletData: wallet?.data,
    });
    if (planned.merged.walletConflict) {
      throw new Error('A wallet conflict appeared after the dry run.');
    }
    if (!planned.needsWrite) {
      await rollback(transaction);
      return 'unchanged';
    }

    planned.normalized.walletVersion = Math.min(
      planned.normalized.walletVersion + 1,
      Number.MAX_SAFE_INTEGER,
    );
    const updateData = {
      ...planned.normalized,
      legacyMigrationVersion: LEGACY_MIGRATION_VERSION,
      legacyMigrationSources: planned.merged.sources,
      legacyMigrationBackupUri: backupUri,
    };
    const writes = [{
      update: {
        name: docPath('server_progress', id),
        fields: encodeFields(updateData),
      },
      updateMask: { fieldPaths: Object.keys(updateData) },
      updateTransforms: [
        { fieldPath: 'legacyMigratedAt', setToServerValue: 'REQUEST_TIME' },
        { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ],
    }];
    await api('/documents:commit', {
      method: 'POST',
      body: { transaction, writes },
    });
    return server ? 'updated' : 'created';
  } catch (error) {
    try {
      await rollback(transaction);
    } catch (_) {
      // Commit closes a transaction, and a failed/aborted transaction may no
      // longer be rollback-able. Preserve the original error.
    }
    if ([409, 429, 500, 503].includes(error.status) && attempt < 4) {
      return migrateOne(id, attempt + 1);
    }
    throw error;
  }
}

async function runConcurrent(items, fn) {
  let cursor = 0;
  const results = [];
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await fn(items[index]);
    }
  }));
  return results;
}

const initial = buildPlan(await readState());
console.log(JSON.stringify({
  mode: apply ? 'apply' : 'dry-run',
  projectId,
  migrationVersion: LEGACY_MIGRATION_VERSION,
  ...initial.summary,
}, null, 2));

if (initial.summary.walletConflicts > 0) {
  throw new Error(
    'Refusing migration because authoritative and legacy wallets conflict.',
  );
}

if (apply) {
  const results = await runConcurrent(initial.writes, migrateOne);
  const applied = results.reduce((counts, result) => {
    counts[result] = (counts[result] || 0) + 1;
    return counts;
  }, {});
  const verification = buildPlan(await readState());
  console.log(JSON.stringify({
    mode: 'verification',
    projectId,
    applied,
    remainingWrites: verification.writes.length,
    ...verification.summary,
  }, null, 2));
  if (
    verification.writes.length !== 0 ||
    verification.summary.walletConflicts !== 0
  ) {
    throw new Error('Post-migration verification did not converge.');
  }
}
