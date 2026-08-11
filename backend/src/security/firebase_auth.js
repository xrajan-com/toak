const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');

const ACCOUNT_DELETIONS_COLLECTION = 'account_deletions';

class AccountDeletedError extends Error {
  constructor() {
    super('This account has been deleted.');
    this.name = 'AccountDeletedError';
    this.code = 'account_deleted';
    this.statusCode = 410;
  }
}

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

  if (admin.getApps().length > 0) {
    _app = admin.getApp();
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

async function _verifyFirebaseIdToken(authClient, token) {
  return authClient.verifyIdToken(token, true);
}

async function requireFirebaseAuth(req, res, next) {
  try {
    const token = _bearerToken(req);
    if (!token) {
      return res.status(401).json({ error: 'Missing Firebase ID token' });
    }

    // Checking revocation is intentional here. A signature-valid token must not
    // remain usable after the account is disabled, revoked, or deleted.
    const decoded = await _verifyFirebaseIdToken(
      getAuth(firebaseAdminApp()),
      token,
    );
    req.auth = decoded;
    return next();
  } catch (error) {
    // Keep authentication failures opaque to callers, but retain enough
    // server-side detail to distinguish malformed tokens from IAM or Firebase
    // configuration failures. Never log the bearer token or decoded claims.
    console.warn(JSON.stringify({
      severity: 'WARNING',
      event: 'firebase_auth_rejected',
      errorName: error?.name || 'Error',
      errorCode: error?.code || 'unknown',
      errorMessage: error?.message || 'Firebase token verification failed',
    }));
    return res.status(401).json({ error: 'Invalid Firebase ID token' });
  }
}

function _isRegisteredFirebaseAuth(auth) {
  const provider = auth?.firebase?.sign_in_provider;
  return typeof provider === 'string' &&
    provider.length > 0 &&
    provider !== 'anonymous';
}

function _requireRegisteredUser(req, res, next) {
  if (!_isRegisteredFirebaseAuth(req.auth)) {
    return res.status(403).json({
      code: 'registered_account_required',
      error: 'Register or sign in to use the shared AUP economy.',
      requestId: req.requestId,
    });
  }
  return next();
}

async function requireRegisteredFirebaseAuth(req, res, next) {
  return requireFirebaseAuth(req, res, () =>
    _requireRegisteredUser(req, res, next));
}

function accountDeletionRef(db, uid) {
  return db.collection(ACCOUNT_DELETIONS_COLLECTION).doc(uid);
}

async function assertAccountActiveInTransaction({ tx, db, uid }) {
  const tombstone = await tx.get(accountDeletionRef(db, uid));
  if (tombstone.exists) throw new AccountDeletedError();
}

function isAccountDeletedError(error) {
  return error?.code === 'account_deleted';
}

module.exports = {
  ACCOUNT_DELETIONS_COLLECTION,
  AccountDeletedError,
  _isRegisteredFirebaseAuth,
  _requireRegisteredUser,
  _verifyFirebaseIdToken,
  accountDeletionRef,
  assertAccountActiveInTransaction,
  firebaseAdminApp,
  isAccountDeletedError,
  requireFirebaseAuth,
  requireRegisteredFirebaseAuth,
};
