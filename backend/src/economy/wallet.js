// Opening a wallet: what the app reads at launch and after every game.
const { reconcileExpiredReservations } = require('./progress');
const { saveProgress, withWallet } = require('./store');

/**
 * The player's wallet. Saves it when opening changed something: a new
 * wallet, the starter grant, an old circuit layout, or an expired entry
 * refunded.
 */
async function walletForUser({ db, uid }) {
  return withWallet(db, uid, ({
    tx,
    ref,
    progress,
    existed,
    normalizedCircuitAup,
    starterGranted,
    auraChanged,
  }) => {
    const refunded = reconcileExpiredReservations(progress);
    if (!existed || normalizedCircuitAup || refunded > 0 || starterGranted) {
      saveProgress(tx, ref, progress);
    }
    return { exists: true, auraChanged: auraChanged(), progress };
  });
}

module.exports = { walletForUser };
