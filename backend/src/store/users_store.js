const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const _defaultStoreFile = path.join(__dirname, '..', '..', 'data', 'users.json');
const _storeFile = (process.env.USER_STORE_FILE ?? _defaultStoreFile).toString();

let _writeChain = Promise.resolve();

function toPublicUser(u) {
  return {
    id: u.id,
    email: u.email,
    username: u.username,
    createdAt: u.createdAt,
  };
}

async function ensureUserStore() {
  const dir = path.dirname(_storeFile);
  await fs.mkdir(dir, { recursive: true });
  try {
    await fs.access(_storeFile);
  } catch (e) {
    if (e && e.code !== 'ENOENT') throw e;
    const empty = { users: [] };
    await fs.writeFile(_storeFile, JSON.stringify(empty, null, 2), 'utf8');
  }
}

async function _readStore() {
  await ensureUserStore();
  const raw = await fs.readFile(_storeFile, 'utf8');
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || !Array.isArray(parsed.users)) {
      return { users: [] };
    }
    return parsed;
  } catch (_) {
    return { users: [] };
  }
}

async function _writeStore(next) {
  const dir = path.dirname(_storeFile);
  const tmp = path.join(dir, `.${path.basename(_storeFile)}.${Date.now()}.tmp`);

  _writeChain = _writeChain.then(async () => {
    await fs.writeFile(tmp, JSON.stringify(next, null, 2), 'utf8');
    await fs.rename(tmp, _storeFile);
  });
  return _writeChain;
}

async function findUserByEmail(email) {
  const store = await _readStore();
  const needle = email.trim().toLowerCase();
  return store.users.find((u) => String(u.email).toLowerCase() === needle) ?? null;
}

async function findUserById(id) {
  const store = await _readStore();
  const user = store.users.find((u) => String(u.id) === String(id)) ?? null;
  return user ? toPublicUser(user) : null;
}

async function createUser({ email, username, passwordHash }) {
  const store = await _readStore();
  const emailNorm = email.trim().toLowerCase();
  const usernameNorm = username.trim();

  const emailTaken = store.users.some((u) => String(u.email).toLowerCase() === emailNorm);
  if (emailTaken) {
    const err = new Error('Email already registered');
    err.code = 'EMAIL_TAKEN';
    throw err;
  }

  const usernameTaken = store.users.some(
    (u) => String(u.username).toLowerCase() === usernameNorm.toLowerCase(),
  );
  if (usernameTaken) {
    const err = new Error('Username already taken');
    err.code = 'USERNAME_TAKEN';
    throw err;
  }

  const user = {
    id: crypto.randomUUID(),
    email: emailNorm,
    username: usernameNorm,
    passwordHash: String(passwordHash),
    createdAt: Date.now(),
  };
  store.users.push(user);
  await _writeStore(store);
  return toPublicUser(user);
}

module.exports = {
  ensureUserStore,
  toPublicUser,
  findUserByEmail,
  findUserById,
  createUser,
};
