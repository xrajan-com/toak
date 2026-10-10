#!/usr/bin/env node
/*
 * One-off: stores totalAup on every server_progress wallet saved before the
 * field existed, so the global rank counts every player from day one.
 * New saves write it themselves; this only catches up old wallets.
 *
 *   gcloud auth application-default login          # once, as a project owner
 *   node backend/scripts/backfill_total_aup.js            # dry run, changes nothing
 *   node backend/scripts/backfill_total_aup.js --apply    # writes
 *
 * Safe to re-run: it only touches wallets whose stored total is missing or
 * wrong, and it writes nothing but that one field.
 */
const { baseProgress, totalAup } = require('../src/economy/progress');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const { connect, run } = require('./firestore_admin');

const apply = process.argv.includes('--apply');

async function main() {
  const { db, projectId } = await connect();
  let scanned = 0;
  let fixed = 0;
  let last = null;
  for (;;) {
    let query = db.collection(SERVER_PROGRESS_COLLECTION).orderBy('__name__').limit(400);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    const batch = db.batch();
    let writes = 0;
    for (const doc of page.docs) {
      scanned += 1;
      const total = totalAup(baseProgress(doc.data()));
      if (doc.get('totalAup') !== total) {
        fixed += 1;
        if (apply) {
          batch.set(doc.ref, { totalAup: total }, { merge: true });
          writes += 1;
        }
      }
    }
    if (writes) await batch.commit();
    last = page.docs[page.docs.length - 1];
    console.log(`  ${scanned} wallets checked`);
  }
  console.log(`${projectId}: scanned ${scanned} wallets, ${fixed} ${apply ? 'updated' : 'need totalAup (dry run, nothing written; add --apply)'}`);
}

run(main, 'Backfill');
