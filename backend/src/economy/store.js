// Where wallets live in Firestore, and the one transaction shape every
// economy operation runs in.
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const {
  assertAccountActiveInTransaction,
  firebaseAdminApp,
} = require('../security/firebase_auth');
const { MIGRATION_COMPLETE_VERSION } = require('./constants');
const {
  CIRCUIT_FIELDS,
  baseProgress,
  clamp,
  grantRegisteredStarterAup,
  int,
  totalAup,
} = require('./progress');

// One document per player, keyed by Firebase uid: the authoritative wallet.
const SERVER_PROGRESS_COLLECTION = 'server_progress';
// One document per applied event, so a retried request never pays twice.
const ECONOMY_RECEIPTS_COLLECTION = 'economy_receipts';

function firestore() {
  return getFirestore(firebaseAdminApp());
}

function walletRef(db, uid) {
  return db.collection(SERVER_PROGRESS_COLLECTION).doc(uid);
}

async function _loadProgress(tx, ref) {
  const snap = await tx.get(ref);
  if (!snap.exists) {
    // A wallet created now has no older economy to merge.
    return {
      existed: false,
      normalizedCircuitAup: false,
      progress: baseProgress({
        legacyMigrationVersion: MIGRATION_COMPLETE_VERSION,
      }),
    };
  }
  const data = snap.data() || {};
  const progress = baseProgress(data);
  return {
    existed: true,
    normalizedCircuitAup: CIRCUIT_FIELDS.some(
      (field) => int(data[field]) !== progress[field],
    ),
    progress,
  };
}

/** Queues the wallet write in `tx`, bumping its version and stored total. */
function saveProgress(tx, ref, progress, extraFields = {}) {
  progress.walletVersion = clamp(
    progress.walletVersion + 1,
    0,
    Number.MAX_SAFE_INTEGER,
  );
  tx.set(
    ref,
    {
      ...progress,
      ...extraFields,
      // Denormalised so the global rank is one indexed count query.
      totalAup: totalAup(progress),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/**
 * Runs `work` in one Firestore transaction on the player's wallet. Before it
 * runs, a deleted account is refused, the wallet is loaded (or started), and
 * a registered player's starter AUP is granted in memory. `work` decides
 * whether to save, and gets:
 *   tx, ref                 the transaction and the wallet document
 *   progress                the wallet, already normalised
 *   existed                 whether the document existed before
 *   normalizedCircuitAup    whether loading changed stored circuit balances
 *   starterGranted          whether the starter grant happened just now
 *   auraChanged()           whether the total has moved since loading
 */
async function withWallet(db, uid, work) {
  const ref = walletRef(db, uid);
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction({ tx, db, uid });
    const loaded = await _loadProgress(tx, ref);
    const { progress } = loaded;
    const totalBefore = totalAup(progress);
    const starterBefore = progress.registeredStarterGranted;
    grantRegisteredStarterAup(progress);
    return work({
      tx,
      ref,
      progress,
      existed: loaded.existed,
      normalizedCircuitAup: loaded.normalizedCircuitAup,
      starterGranted: starterBefore !== progress.registeredStarterGranted,
      auraChanged: () => totalAup(progress) !== totalBefore,
    });
  });
}

module.exports = {
  ECONOMY_RECEIPTS_COLLECTION,
  SERVER_PROGRESS_COLLECTION,
  firestore,
  saveProgress,
  walletRef,
  withWallet,
};
