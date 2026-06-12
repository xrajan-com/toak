const jwt = require('jsonwebtoken');

function _jwtSecret() {
  const secret = (process.env.JWT_SECRET ?? '').toString().trim();
  if (secret) return secret;
  if (process.env.NODE_ENV !== 'production') {
    return 'dev_insecure_jwt_secret_change_me';
  }
  throw new Error('JWT_SECRET is required');
}

function signToken({ userId, email, username }) {
  const secret = _jwtSecret();
  const expiresIn = (process.env.JWT_EXPIRES_IN ?? '7d').toString();
  return jwt.sign(
    {
      sub: userId,
      email,
      username,
    },
    secret,
    {
      expiresIn,
      issuer: 'tenofakind-backend',
    },
  );
}

function requireAuth(req, res, next) {
  const header = (req.headers.authorization ?? '').toString();
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return res.status(401).json({ error: 'Missing bearer token' });

  try {
    req.auth = jwt.verify(match[1], _jwtSecret(), {
      issuer: 'tenofakind-backend',
    });
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = { signToken, requireAuth };
