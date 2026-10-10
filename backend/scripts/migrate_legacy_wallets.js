#!/usr/bin/env node
/*
 * One-off, before deploying the backend that no longer migrates old wallets
 * itself. Brings every remaining pre-server wallet onto its server wallet,
 * exactly as the server did while ALLOW_LEGACY_CLIENT_ECONOMY_MIGRATION was
 * on:
 *   - a player with campaign_progress or aura_wallets data but no server
 *     wallet;
 *   - a server wallet still below the migration marker, which the app
 *     refuses to use ("economy migration pending").
 *
 *   gcloud auth application-default login          # once, as a project owner
 *   node backend/scripts/migrate_legacy_wallets.js           # dry run, changes nothing
 *   node backend/scripts/migrate_legacy_wallets.js --apply   # writes
 *
 * Safe to re-run: a migrated wallet is skipped. A wallet whose old balance
 * disagrees with its server balance is listed and left alone for a person
 * to decide, as the server used to refuse it.
 */
const { MIGRATION_COMPLETE_VERSION } = require('../src/economy/constants');
const { baseProgress, int } = require('../src/economy/progress');
const {
  SERVER_PROGRESS_COLLECTION,
  saveProgress,
  walletRef,
} = require('../src/economy/store');
const { accountDeletionRef } = require('../src/security/firebase_auth');
const { mergeLegacyEconomy } = require('./legacy_wallet_merge');

const LEGACY_PROGRESS_COLLECTION = 'campaign_progress';
const CLIENT_WALLET_COLLECTION = 'aura_wallets';

/**
 * Migrates one player in a transaction. Returns { outcome } where outcome is
 * 'migrated' (or would be, without apply), 'current', 'conflict', 'deleted'
 * or 'none'.
 */
async function migrateLegacyWallet({ db, uid, apply = false }) {
  const serverRef = walletRef(db, uid);
  const campaignRef = db.collection(LEGACY_PROGRESS_COLLECTION).doc(uid);
  const clientWalletRef = db.collection(CLIENT_WALLET_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    const tombstone = await tx.get(accountDeletionRef(db, uid));
    const serverSnap = await tx.get(serverRef);
    const campaignSnap = await tx.get(campaignRef);
    const clientWalletSnap = await tx.get(clientWalletRef);
    if (tombstone.exists) return { outcome: 'deleted' };

    const serverData = serverSnap.exists ? (serverSnap.data() || {}) : {};
    if (
      serverSnap.exists &&
      int(serverData.legacyMigrationVersion) >= MIGRATION_COMPLETE_VERSION
    ) {
      return { outcome: 'current' };
    }
    if (!serverSnap.exists && !campaignSnap.exists && !clientWalletSnap.exists) {
      return { outcome: 'none' };
    }

    const merged = mergeLegacyEconomy({
      serverData,
      campaignData: campaignSnap.exists ? campaignSnap.data() : null,
      walletData: clientWalletSnap.exists ? clientWalletSnap.data() : null,
    });
    if (merged.walletConflict) return { outcome: 'conflict' };
    if (apply) {
      saveProgress(tx, serverRef, baseProgress(merged.data), {
        legacyMigrationSources: merged.sources,
        ...(merged.sources.length > 0
          ? { migratedFrom: merged.sources.join('+') }
          : {}),
      });
    }
    return { outcome: 'migrated', sources: merged.sources };
  });
}

async function _candidateUids(db) {
  const uids = new Set();
  for (const name of [LEGACY_PROGRESS_COLLECTION, CLIENT_WALLET_COLLECTION]) {
    for (const ref of await db.collection(name).listDocuments()) uids.add(ref.id);
  }
  // Server wallets below the marker, including ones with no marker at all,
  // which a where() query cannot find.
  let last = null;
  for (;;) {
    let query = db.collection(SERVER_PROGRESS_COLLECTION)
      .select('legacyMigrationVersion')
      .orderBy('__name__')
      .limit(500);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      if (int(doc.get('legacyMigrationVersion')) < MIGRATION_COMPLETE_VERSION) {
        uids.add(doc.id);
      }
    }
    last = page.docs[page.docs.length - 1];
  }
  return [...uids].sort();
}

async function main() {
  const { execFileSync } = require('node:child_process');
  const path = require('node:path');
  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');

  const apply = process.argv.includes('--apply');
  const root = path.join(__dirname, '..', '..');
  const projectId = execFileSync(
    'bash',
    [path.join(root, 'tools/project_config.sh'), 'backend.gcp_project'],
  ).toString().trim();
  // Bill API quota to this project, whatever project the Mac's gcloud login
  // happens to default to.
  process.env.GOOGLE_CLOUD_QUOTA_PROJECT = projectId;
  const db = getFirestore(
    initializeApp({ credential: applicationDefault(), projectId }),
  );

  const counts = { migrated: 0, current: 0, conflict: 0, deleted: 0, none: 0 };
  const conflicts = [];
  for (const uid of await _candidateUids(db)) {
    const { outcome } = await migrateLegacyWallet({ db, uid, apply });
    counts[outcome] += 1;
    if (outcome === 'conflict') conflicts.push(uid);
  }
  console.log(
    `${projectId}: ${counts.migrated} wallet(s) ` +
    `${apply ? 'migrated' : 'to migrate (dry run, nothing written; add --apply)'}, ` +
    `${counts.current} already current, ${counts.deleted} deleted account(s), ` +
    `${counts.conflict} conflict(s).`,
  );
  if (conflicts.length > 0) {
    console.log('Old and server balances disagree; left untouched:');
    for (const uid of conflicts) console.log(`  ${uid}`);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error('Migration failed:', error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  CLIENT_WALLET_COLLECTION,
  LEGACY_PROGRESS_COLLECTION,
  migrateLegacyWallet,
};
