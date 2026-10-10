// Shared start-up for the one-off data scripts: connects to the production
// Firestore named in project.yaml with your gcloud login, and fails fast
// with a plain message instead of hanging when it cannot.
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const CONNECT_TIMEOUT_MS = 30 * 1000;

function withTimeout(promise, ms, message) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error(message)), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

async function connect() {
  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');

  const root = path.join(__dirname, '..', '..');
  const projectId = execFileSync(
    'bash',
    [path.join(root, 'tools/project_config.sh'), 'backend.gcp_project'],
  ).toString().trim();
  // Bill API quota to this project, whatever project the Mac's gcloud login
  // happens to default to.
  process.env.GOOGLE_CLOUD_QUOTA_PROJECT = projectId;

  console.log(`Connecting to Firestore in ${projectId}...`);
  const db = getFirestore(
    initializeApp({ credential: applicationDefault(), projectId }),
  );
  await withTimeout(
    db.collection('server_progress').limit(1).get(),
    CONNECT_TIMEOUT_MS,
    `No answer from Firestore in ${CONNECT_TIMEOUT_MS / 1000} s. Check the ` +
      'internet connection, then run: gcloud auth application-default login',
  );
  console.log('Connected.');
  return { db, projectId };
}

/** Runs a script's main(), printing a failure plainly and always exiting. */
function run(main, label) {
  const startedAt = Date.now();
  main()
    .then(() => {
      console.log(`Done in ${Math.round((Date.now() - startedAt) / 1000)} s.`);
      process.exit(0);
    })
    .catch((error) => {
      console.error(`${label} failed: ${error.message}`);
      process.exit(1);
    });
}

module.exports = { connect, run, withTimeout };
