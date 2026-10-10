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
    const refs = await db.collection(name).listDocuments();
    console.log(`  ${name}: ${refs.length} player(s) with old data`);
    for (const ref of refs) uids.add(ref.id);
  }
  // Server wallets below the marker, including ones with no marker at all,
  // which a where() query cannot find.
  let last = null;
  let scanned = 0;
  let unfinished = 0;
  for (;;) {
    let query = db.collection(SERVER_PROGRESS_COLLECTION)
      .select('legacyMigrationVersion')
      .orderBy('__name__')
      .limit(500);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      scanned += 1;
      if (int(doc.get('legacyMigrationVersion')) < MIGRATION_COMPLETE_VERSION) {
        unfinished += 1;
        uids.add(doc.id);
      }
    }
    last = page.docs[page.docs.length - 1];
  }
  console.log(
    `  ${SERVER_PROGRESS_COLLECTION}: ${scanned} wallet(s), ` +
    `${unfinished} not yet marked migrated`,
  );
  return [...uids].sort();
}

// One batched read per 100 players drops everyone whose server wallet is
// already migrated, so only the stragglers need a transaction each.
async function _needingMigration(db, uids) {
  const remaining = [];
  for (let i = 0; i < uids.length; i += 100) {
    const chunk = uids.slice(i, i + 100);
    const snaps = await db.getAll(...chunk.map((uid) => walletRef(db, uid)));
    snaps.forEach((snap, index) => {
      const migrated = snap.exists &&
        int(snap.get('legacyMigrationVersion')) >= MIGRATION_COMPLETE_VERSION;
      if (!migrated) remaining.push(chunk[index]);
    });
  }
  return remaining;
}

async function main() {
  const { connect } = require('./firestore_admin');
  const apply = process.argv.includes('--apply');
  const { db, projectId } = await connect();

  console.log('Finding players with old-style wallets...');
  const candidates = await _candidateUids(db);
  const remaining = await _needingMigration(db, candidates);
  console.log(
    `${candidates.length - remaining.length} already migrated; ` +
    `checking the other ${remaining.length} one by one...`,
  );

  const counts = {
    migrated: 0,
    current: candidates.length - remaining.length,
    conflict: 0,
    deleted: 0,
    none: 0,
  };
  const conflicts = [];
  for (const [index, uid] of remaining.entries()) {
    const { outcome } = await migrateLegacyWallet({ db, uid, apply });
    counts[outcome] += 1;
    if (outcome === 'conflict') conflicts.push(uid);
    if ((index + 1) % 25 === 0) console.log(`  ${index + 1} / ${remaining.length}`);
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
  require('./firestore_admin').run(main, 'Migration');
}

module.exports = {
  CLIENT_WALLET_COLLECTION,
  LEGACY_PROGRESS_COLLECTION,
  migrateLegacyWallet,
};
