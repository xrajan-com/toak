const admin = require('firebase-admin');

let _app;

function _projectId() {
  return (
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    undefined
  );
}

function firebaseAdminApp() {
  if (_app) return _app;

  if (admin.apps.length > 0) {
    _app = admin.app();
    return _app;
  }

  const projectId = _projectId();
  _app = admin.initializeApp(projectId ? { projectId } : undefined);
  return _app;
}

function _bearerToken(req) {
  const header = req.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : '';
}

async function requireFirebaseAuth(req, res, next) {
  try {
    const token = _bearerToken(req);
    if (!token) {
      return res.status(401).json({ error: 'Missing Firebase ID token' });
    }

    const decoded = await firebaseAdminApp().auth().verifyIdToken(token);
    req.auth = decoded;
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid Firebase ID token' });
  }
}

module.exports = {
  firebaseAdminApp,
  requireFirebaseAuth,
};
