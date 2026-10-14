const test = require('node:test');
const assert = require('node:assert/strict');

const { appCheckGate, appCheckMode } = require('../src/security/app_check');

function fakeReq(token) {
  return {
    requestId: 'req-12345678',
    method: 'POST',
    path: '/v1/economy/events',
    get: (name) => (name.toLowerCase() === 'x-firebase-appcheck' ? token : undefined),
  };
}

function fakeRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

async function run(gate, token) {
  const req = fakeReq(token);
  const res = fakeRes();
  let passed = false;
  const warn = console.warn;
  console.warn = () => {};
  try {
    await gate(req, res, () => { passed = true; });
  } finally {
    console.warn = warn;
  }
  return { req, res, passed };
}

const verify = async (token) => {
  if (token === 'good') return { appId: '1:android:abc' };
  throw new Error('bad token');
};

test('App Check is off outside production and monitors in production', () => {
  assert.equal(appCheckMode({}), 'off');
  assert.equal(appCheckMode({ NODE_ENV: 'production' }), 'monitor');
  assert.equal(appCheckMode({ NODE_ENV: 'production', APP_CHECK_MODE: 'enforce' }), 'enforce');
  assert.equal(appCheckMode({ NODE_ENV: 'production', APP_CHECK_MODE: 'nonsense' }), 'monitor');
  assert.equal(appCheckMode({ APP_CHECK_MODE: 'OFF' }), 'off');
});

test('monitor mode lets old builds without a token through', async () => {
  const gate = appCheckGate({ mode: 'monitor', verify });
  assert.equal((await run(gate, undefined)).passed, true);
  assert.equal((await run(gate, 'forged')).passed, true);
});

test('enforce mode refuses a missing or forged token and accepts a real one', async () => {
  const gate = appCheckGate({ mode: 'enforce', verify });

  const missing = await run(gate, undefined);
  assert.equal(missing.passed, false);
  assert.equal(missing.res.statusCode, 401);
  assert.equal(missing.res.body.code, 'app_check_required');

  const forged = await run(gate, 'forged');
  assert.equal(forged.passed, false);
  assert.equal(forged.res.statusCode, 401);

  const real = await run(gate, 'good');
  assert.equal(real.passed, true);
  assert.deepEqual(real.req.appCheck, { appId: '1:android:abc' });
});

test('off mode never calls the verifier', async () => {
  let called = false;
  const gate = appCheckGate({ mode: 'off', verify: async () => { called = true; } });
  assert.equal((await run(gate, 'anything')).passed, true);
  assert.equal(called, false);
});
