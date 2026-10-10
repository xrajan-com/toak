const assert = require('node:assert/strict');
const { test } = require('node:test');

const { clientKey } = require('../src/security/rate_limit');

function fakeRequest({ authorization, auth, ip = '203.0.113.7' } = {}) {
  return {
    ip,
    auth,
    get: (name) => (name.toLowerCase() === 'authorization' ? authorization : undefined),
  };
}

function unsignedToken(claims) {
  const part = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${part({ alg: 'RS256' })}.${part(claims)}.signature`;
}

test('rate limits count per player: verified uid, then token uid, then IP', () => {
  const token = unsignedToken({ user_id: 'player-123', sub: 'player-123' });

  assert.equal(
    clientKey(fakeRequest({ auth: { uid: 'verified-uid' }, authorization: `Bearer ${token}` })),
    'uid:verified-uid',
  );
  assert.equal(
    clientKey(fakeRequest({ authorization: `Bearer ${token}` })),
    'token:player-123',
  );
  assert.equal(clientKey(fakeRequest()), 'ip:203.0.113.7');
  // Garbage never becomes a key; it falls back to the IP.
  assert.equal(
    clientKey(fakeRequest({ authorization: 'Bearer not-a-jwt' })),
    'ip:203.0.113.7',
  );
  assert.equal(
    clientKey(fakeRequest({
      authorization: `Bearer ${unsignedToken({ sub: '../../etc' })}`,
    })),
    'ip:203.0.113.7',
  );
});
