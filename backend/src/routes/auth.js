const express = require('express');
const rateLimit = require('express-rate-limit');

const { requireFirebaseAuth } = require('../security/firebase_auth');

function _asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
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

  return router;
}

module.exports = { authRouter };
