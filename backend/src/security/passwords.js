const crypto = require('node:crypto');
const { promisify } = require('node:util');

const scryptAsync = promisify(crypto.scrypt);

const _kKeyLen = 64;
const _kScryptParams = {
  N: 16384,
  r: 8,
  p: 1,
  maxmem: 64 * 1024 * 1024,
};

async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = await scryptAsync(password, salt, _kKeyLen, _kScryptParams);
  return [
    'scrypt',
    _kScryptParams.N,
    _kScryptParams.r,
    _kScryptParams.p,
    salt,
    derived.toString('hex'),
  ].join('$');
}

async function verifyPassword(password, stored) {
  try {
    const parts = String(stored).split('$');
    if (parts.length !== 6) return false;
    const [algo, nRaw, rRaw, pRaw, salt, expectedHex] = parts;
    if (algo !== 'scrypt') return false;
    const N = Number.parseInt(nRaw, 10);
    const r = Number.parseInt(rRaw, 10);
    const p = Number.parseInt(pRaw, 10);
    if (!Number.isFinite(N) || !Number.isFinite(r) || !Number.isFinite(p)) return false;
    const expected = Buffer.from(expectedHex, 'hex');
    const derived = await scryptAsync(password, salt, expected.length, {
      N,
      r,
      p,
      maxmem: _kScryptParams.maxmem,
    });
    return (
      expected.length === derived.length &&
      crypto.timingSafeEqual(expected, Buffer.from(derived))
    );
  } catch (_) {
    return false;
  }
}

module.exports = { hashPassword, verifyPassword };
