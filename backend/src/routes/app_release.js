const express = require('express');
const { getFirestore } = require('firebase-admin/firestore');

const { firebaseAdminApp } = require('../security/firebase_auth');

const RUNTIME_CONFIG_COLLECTION = 'runtime_config';
const APP_RELEASE_DOCUMENT = 'app_release';

// runtime_config stays sealed to clients in firestore.rules; the admin SDK
// bypasses rules, so this route is the only way the value reaches a player.
// Launches arrive in bursts and the document only changes when a release
// ships, so serve it from a short cache rather than spending one Firestore
// read per app open.
const CACHE_TTL_MS = 60 * 1000;
const EMPTY = Object.freeze({
  latestBuild: null,
  message: null,
  storeUrl: null,
});

let _cached = null;
let _cachedAtMs = 0;

function _db() {
  return getFirestore(firebaseAdminApp());
}

// Both paths accept the same range: a positive integer of at most nine
// digits. Without the upper bound the numeric path would happily forward
// something like 1.5e300, and every client would read itself as hopelessly
// out of date.
const MAX_BUILD_NUMBER = 999999999;

function _inBuildRange(value) {
  return value > 0 && value <= MAX_BUILD_NUMBER ? value : null;
}

function _asBuildNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return _inBuildRange(Math.trunc(value));
  }
  if (typeof value === 'string' && /^\d{1,9}$/.test(value.trim())) {
    return _inBuildRange(Number.parseInt(value.trim(), 10));
  }
  return null;
}

function _asText(value, maxLength) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, maxLength) : null;
}

function _asHttpsUrl(value) {
  const raw = _asText(value, 500);
  if (raw === null) return null;
  let parsed;
  try {
    parsed = new URL(raw);
  } catch (_) {
    return null;
  }
  // https only. The client opens this in a browser, so a mistyped or tampered
  // document must not be able to hand players a javascript:, intent: or
  // market: target.
  return parsed.protocol === 'https:' ? parsed.toString() : null;
}

function _shapeAppRelease(data) {
  if (!data || typeof data !== 'object') return { ...EMPTY };
  return {
    latestBuild: _asBuildNumber(data.latestBuild),
    message: _asText(data.message, 240),
    storeUrl: _asHttpsUrl(data.storeUrl),
  };
}

async function _readAppRelease() {
  const now = Date.now();
  if (_cached && now - _cachedAtMs < CACHE_TTL_MS) return _cached;

  const snapshot = await _db()
    .collection(RUNTIME_CONFIG_COLLECTION)
    .doc(APP_RELEASE_DOCUMENT)
    .get();

  _cached = _shapeAppRelease(snapshot.exists ? snapshot.data() : null);
  _cachedAtMs = now;
  return _cached;
}

function appReleaseRouter() {
  const router = express.Router();

  // Deliberately unauthenticated: an update notice has to reach a player
  // before they sign in, and the payload carries nothing user-specific.
  //
  // A read failure answers with nulls rather than 500. A Firestore outage
  // must never convince a client it is out of date, and must never turn into
  // a launch-blocking error on the client's side.
  router.get('/', async (req, res) => {
    try {
      return res.json(await _readAppRelease());
    } catch (error) {
      console.log(JSON.stringify({
        severity: 'WARNING',
        event: 'app_release_read_failed',
        requestId: req.requestId,
        errorCode: error?.code || 'internal',
      }));
      return res.json({ ...EMPTY });
    }
  });

  return router;
}

module.exports = {
  appReleaseRouter,
  APP_RELEASE_DOCUMENT,
  RUNTIME_CONFIG_COLLECTION,
  _shapeAppRelease,
  _asHttpsUrl,
  _resetAppReleaseCache() {
    _cached = null;
    _cachedAtMs = 0;
  },
};
