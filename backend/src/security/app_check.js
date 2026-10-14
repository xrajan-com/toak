// Firebase App Check: proof that a request comes from a real copy of the app
// (Play Integrity on Android, DeviceCheck on iOS), not from a script.
//
// The app sends its App Check token in the X-Firebase-AppCheck header. Checking
// it is a local signature check against Google's cached public keys, so it
// adds no network round trip per request.
//
// APP_CHECK_MODE decides what happens to a request without a valid token:
//   off      - not checked at all (the default outside production)
//   monitor  - let through, but logged as an `app_check` event (the default in
//              production). Builds before build 88 send no token, so this is the
//              only safe mode while they are still in players' hands.
//   enforce  - refused with 401 app_check_required. Turn this on once the
//              logs show almost every request carries a valid token.
const { getAppCheck } = require('firebase-admin/app-check');

const { firebaseAdminApp } = require('./firebase_auth');

const APP_CHECK_HEADER = 'x-firebase-appcheck';
const APP_CHECK_MODES = new Set(['off', 'monitor', 'enforce']);

function appCheckMode(env = process.env) {
  const raw = String(env.APP_CHECK_MODE ?? '').trim().toLowerCase();
  if (APP_CHECK_MODES.has(raw)) return raw;
  return env.NODE_ENV === 'production' ? 'monitor' : 'off';
}

async function _defaultVerify(token) {
  return getAppCheck(firebaseAdminApp()).verifyToken(token);
}

/**
 * Express middleware. `verify` is injectable for tests; it must resolve for a
 * valid token and reject for anything else.
 */
function appCheckGate({ mode = appCheckMode(), verify = _defaultVerify } = {}) {
  return async function requireAppCheck(req, res, next) {
    if (mode === 'off') return next();

    const token = (req.get(APP_CHECK_HEADER) || '').trim();
    let outcome = 'missing';
    if (token) {
      try {
        const result = await verify(token);
        req.appCheck = { appId: result?.appId ?? null };
        return next();
      } catch (_) {
        outcome = 'invalid';
      }
    }

    // Never log the token itself.
    console.warn(JSON.stringify({
      severity: 'WARNING',
      event: 'app_check',
      outcome,
      mode,
      requestId: req.requestId,
      method: req.method,
      path: req.path,
    }));
    if (mode !== 'enforce') return next();
    return res.status(401).json({
      code: 'app_check_required',
      error: 'Update the app to keep playing online.',
      requestId: req.requestId,
    });
  };
}

module.exports = {
  APP_CHECK_HEADER,
  appCheckGate,
  appCheckMode,
};
