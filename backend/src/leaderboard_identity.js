const { createHash } = require('node:crypto');

const LEADERBOARD_ID_PREFIX = 'lb1_';
const LEADERBOARD_ID_DOMAIN =
  'ten-of-a-kind-poker:public-leaderboard:v1\u0000';

/**
 * Returns a stable public document id without publishing the Firebase uid.
 * Firebase uids carry high entropy; domain-separated SHA-256 preserves that
 * entropy while preventing the raw account identifier from appearing in a
 * publicly readable Firestore path.
 */
function leaderboardDocumentId(uid) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new TypeError('A non-empty Firebase uid is required.');
  }

  const digest = createHash('sha256')
    .update(LEADERBOARD_ID_DOMAIN, 'utf8')
    .update(uid, 'utf8')
    .digest('base64url');
  return `${LEADERBOARD_ID_PREFIX}${digest}`;
}

function isOpaqueLeaderboardDocumentId(documentId) {
  return typeof documentId === 'string' &&
    /^lb1_[A-Za-z0-9_-]{43}$/.test(documentId);
}

module.exports = {
  LEADERBOARD_ID_PREFIX,
  isOpaqueLeaderboardDocumentId,
  leaderboardDocumentId,
};
