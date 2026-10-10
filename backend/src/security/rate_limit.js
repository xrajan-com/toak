// Rate limits that count per player, not per IP address.
//
// Players on mobile networks often share one public IP (carrier NAT), and
// requests through tenofakind.com/api reach Cloud Run from Firebase Hosting's
// servers rather than from the phone. Counting per IP would put unrelated
// players in one bucket, so a request is counted under, in order:
//   1. the Firebase uid verified by the auth middleware, when the limiter
//      runs after it (every per-route limiter that guards signed-in work);
//   2. the uid inside the bearer token, read without verifying it. This only
//      chooses a bucket: a forged token buys its own bucket and is then
//      refused by the auth middleware;
//   3. the IP address, for requests that carry no token.
const rateLimit = require('express-rate-limit');

const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

function _unverifiedTokenUid(req) {
  const header = req.get('authorization') || '';
  const match = header.match(/^Bearer\s+([^.\s]+)\.([^.\s]+)\.[^.\s]+$/i);
  if (!match) return '';
  try {
    const claims = JSON.parse(Buffer.from(match[2], 'base64url').toString('utf8'));
    const uid = claims?.user_id ?? claims?.sub;
    return typeof uid === 'string' && UID_PATTERN.test(uid) ? uid : '';
  } catch (_) {
    return '';
  }
}

function clientKey(req) {
  const verifiedUid = req.auth?.uid;
  if (typeof verifiedUid === 'string' && verifiedUid) return `uid:${verifiedUid}`;
  const tokenUid = _unverifiedTokenUid(req);
  if (tokenUid) return `token:${tokenUid}`;
  return `ip:${req.ip}`;
}

/** A per-player limiter: at most `max` requests per `windowMs`. */
function playerRateLimit({ windowMs, max }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: clientKey,
  });
}

module.exports = { clientKey, playerRateLimit };
