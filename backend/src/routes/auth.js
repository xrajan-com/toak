const express = require('express');
const rateLimit = require('express-rate-limit');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const {
  ACCOUNT_DELETIONS_COLLECTION,
  accountDeletionRef,
  firebaseAdminApp,
  requireFirebaseAuth,
} = require('../security/firebase_auth');
const { leaderboardDocumentId } = require('../leaderboard_identity');

const RECENT_AUTH_MAX_AGE_SECONDS = 5 * 60;
const ACCOUNT_DOCUMENT_COLLECTIONS = [
  'users',
  'campaign_progress',
  'aura_wallets',
  'leaderboard',
  'server_progress',
];

function _asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function _isRecentAuth(auth, nowMs = Date.now()) {
  if (!auth || typeof auth.auth_time !== 'number') return false;
  const ageSeconds = Math.floor(nowMs / 1000) - Math.trunc(auth.auth_time);
  return ageSeconds >= 0 && ageSeconds <= RECENT_AUTH_MAX_AGE_SECONDS;
}

async function _deleteAccountData({ db, uid }) {
  await db.runTransaction(async (tx) => {
    const tombstoneRef = accountDeletionRef(db, uid);
    const tombstone = await tx.get(tombstoneRef);

    // The durable lock and deletion of all deterministic user documents are
    // atomic. Economy/leaderboard transactions read this same document, so a
    // request authenticated just before deletion cannot commit afterward.
    if (!tombstone.exists) {
      tx.set(tombstoneRef, {
        schemaVersion: 1,
        state: 'locked',
        lockedAt: FieldValue.serverTimestamp(),
      });
    }
    for (const collection of ACCOUNT_DOCUMENT_COLLECTIONS) {
      tx.delete(db.collection(collection).doc(uid));
    }
    // Current leaderboard rows use a public opaque id; retain the raw uid
    // deletion above so accounts created before the migration are also purged.
    tx.delete(
      db.collection('leaderboard').doc(leaderboardDocumentId(uid)),
    );
  });

  // Receipt ids are event-derived, so remove them in bounded batches after the
  // tombstone is committed. No new receipt can commit once the lock exists.
  for (;;) {
    const receipts = await db
      .collection('economy_receipts')
      .where('uid', '==', uid)
      .limit(400)
      .get();
    const batch = db.batch();
    for (const doc of receipts.docs) batch.delete(doc.ref);
    if (receipts.docs.length > 0) await batch.commit();
    if (receipts.docs.length < 400) break;
  }
}

async function _deleteFirebaseUser(auth, uid) {
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    // Two already-authenticated deletion requests may race. Once the durable
    // tombstone exists, an already-removed Auth user is the desired result.
    if (error?.code !== 'auth/user-not-found') throw error;
  }
}

async function _deleteAccount({ db, auth, uid }) {
  // Auth is deleted last so a transient Firestore cleanup failure can be
  // retried by the user, while the tombstone blocks all state recreation.
  await _deleteAccountData({ db, uid });
  await _deleteFirebaseUser(auth, uid);
}

function authRouter() {
  const router = express.Router();

  const registerLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
  });

  const loginLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 25,
    standardHeaders: true,
    legacyHeaders: false,
  });
  const accountDeleteLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5,
    standardHeaders: true,
    legacyHeaders: false,
  });

  router.post('/register', registerLimiter, (_req, res) => {
    return res.status(410).json({
      error: 'Use Firebase Auth client SDK for registration',
    });
  });

  router.post('/login', loginLimiter, (_req, res) => {
    return res.status(410).json({
      error: 'Use Firebase Auth client SDK for login',
    });
  });

  router.get(
    '/me',
    requireFirebaseAuth,
    _asyncHandler(async (req, res) => {
      const auth = req.auth;
      return res.json({
        user: {
          id: auth.uid,
          uid: auth.uid,
          email: auth.email ?? null,
          emailVerified: auth.email_verified === true,
          displayName: auth.name ?? null,
          picture: auth.picture ?? null,
          signInProvider: auth.firebase?.sign_in_provider ?? null,
        },
      });
    }),
  );

  router.delete(
    '/account',
    accountDeleteLimiter,
    requireFirebaseAuth,
    _asyncHandler(async (req, res) => {
      res.set('Cache-Control', 'no-store');
      if (req.body?.confirmation !== 'DELETE') {
        return res.status(400).json({
          code: 'confirmation_required',
          error: 'Type DELETE to confirm account deletion.',
          requestId: req.requestId,
        });
      }
      if (!_isRecentAuth(req.auth)) {
        return res.status(401).json({
          code: 'recent_login_required',
          error: 'Sign in again before deleting this account.',
          requestId: req.requestId,
        });
      }

      const app = firebaseAdminApp();
      const uid = req.auth.uid;
      await _deleteAccount({
        db: getFirestore(app),
        auth: getAuth(app),
        uid,
      });
      return res.json({
        deleted: true,
        requestId: req.requestId,
      });
    }),
  );

  return router;
}

module.exports = {
  ACCOUNT_DELETIONS_COLLECTION,
  ACCOUNT_DOCUMENT_COLLECTIONS,
  RECENT_AUTH_MAX_AGE_SECONDS,
  _deleteAccount,
  _deleteAccountData,
  _deleteFirebaseUser,
  _isRecentAuth,
  authRouter,
};
