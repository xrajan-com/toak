// A player's place among everyone who has won AUP.
const { baseProgress, totalAup } = require('./progress');
const { SERVER_PROGRESS_COLLECTION } = require('./store');

/**
 * rank = 1 + the number of wallets with strictly more AUP, so ties share a
 * rank. Wallets with no AUP are unranked. Uses Firestore count aggregation:
 * cost grows by one read per thousand wallets counted, not per wallet.
 * A wallet saved before totalAup was stored gets it written here, so the
 * ranking heals itself as players open their dashboards.
 */
async function rankForUser({ db, uid }) {
  const collection = db.collection(SERVER_PROGRESS_COLLECTION);
  const ref = collection.doc(uid);
  const snap = await ref.get();
  const data = snap.exists ? snap.data() : null;
  const total = data ? totalAup(baseProgress(data)) : 0;
  if (data && data.totalAup !== total) {
    await ref.set({ totalAup: total }, { merge: true });
  }
  const rankedPlayers = (
    await collection.where('totalAup', '>', 0).count().get()
  ).data().count;
  if (total <= 0) {
    return { totalAup: 0, rank: null, rankedPlayers };
  }
  const ahead = (
    await collection.where('totalAup', '>', total).count().get()
  ).data().count;
  return {
    totalAup: total,
    rank: ahead + 1,
    rankedPlayers: Math.max(rankedPlayers, ahead + 1),
  };
}

module.exports = { rankForUser };
