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

// Checking revocation costs a round trip to Firebase Auth on every request,
// so only account deletion does it (requireFreshFirebaseAuth). Everywhere
// else the signature and expiry are enough: an ID token lives at most an hour,
// a disabled or deleted account cannot get a new one, and every wallet and
// leaderboard write also refuses deleted accounts inside its own transaction
// (assertAccountActiveInTransaction).
async function _verifyFirebaseIdToken(authClient, token, { checkRevoked = false } = {}) {
  return authClient.verifyIdToken(token, checkRevoked);
}

// Route tests find guards by function name.
function _named(name, fn) {
  return Object.defineProperty(fn, 'name', { value: name });
}

function _firebaseAuthGuard({ checkRevoked }) {
  return async function firebaseAuthGuard(req, res, next) {
    try {
      const token = _bearerToken(req);
      if (!token) {
        return res.status(401).json({ error: 'Missing Firebase ID token' });
      }

      const decoded = await _verifyFirebaseIdToken(
        getAuth(firebaseAdminApp()),
        token,
        { checkRevoked },
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
  };
}

/** Signature and expiry only: no network call. Used by every gameplay route. */
const requireFirebaseAuth = _named(
  'requireFirebaseAuth',
  _firebaseAuthGuard({ checkRevoked: false }),
);

/** Also asks Firebase whether the login was revoked. Account deletion only. */
const requireFreshFirebaseAuth = _named(
  'requireFreshFirebaseAuth',
  _firebaseAuthGuard({ checkRevoked: true }),
);

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
  requireFreshFirebaseAuth,
  requireRegisteredFirebaseAuth,
};
