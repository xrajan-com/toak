#!/usr/bin/env node
/*
 * One-off: fills the Trailblazers board (top 10 by forts cleared) from every
 * wallet saved before the board existed. After this, every fort clear keeps
 * it current by itself.
 *
 *   gcloud auth application-default login                   # once, as a project owner
 *   node backend/scripts/backfill_trailblazers.js            # dry run: prints the top 10
 *   node backend/scripts/backfill_trailblazers.js --apply    # writes the board
 *
 * Safe to re-run: it uses the same transaction the server uses on every fort
 * clear, so it can only ever leave the correct top ten.
 */
const { fortsClearedCount } = require('../src/economy/catalog');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const { _syncTrailblazers } = require('../src/routes/leaderboard');
const { connect, run } = require('./firestore_admin');

const apply = process.argv.includes('--apply');

async function main() {
  const { db, projectId } = await connect();
  const players = [];
  let scanned = 0;
  let last = null;
  for (;;) {
    let page = db.collection(SERVER_PROGRESS_COLLECTION).orderBy('__name__').limit(400);
    if (last) page = page.startAfter(last);
    const snap = await page.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const forts = fortsClearedCount(doc.get('cleared'));
      if (forts > 0) players.push({ uid: doc.id, forts });
    }
    last = snap.docs[snap.docs.length - 1];
    console.log(`  ${scanned} wallets checked`);
  }

  players.sort((a, b) => b.forts - a.forts);
  console.log(`${players.length} players have cleared at least one fort. Most forts:`);
  for (const player of players.slice(0, 10)) {
    console.log(`  ${String(player.forts).padStart(3)} / 500`);
  }
  if (!apply) {
    console.log(`${projectId}: dry run, nothing written. Add --apply to fill the board.`);
    return;
  }

  // Every player with forts goes through the server's own sync, so ties and
  // the ten-row cap are decided exactly as they will be from now on.
  let written = 0;
  for (const player of players) {
    const result = await _syncTrailblazers({ db, uid: player.uid });
    if (result.synced) written += 1;
  }
  console.log(`${projectId}: Trailblazers board filled (${written} row writes).`);
}

run(main, 'Trailblazers backfill');
