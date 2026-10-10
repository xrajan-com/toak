const assert = require('node:assert/strict');
const http = require('node:http');
const { test } = require('node:test');

const { createApp } = require('../src/index');

async function withServer(fn) {
  const server = http.createServer(createApp());
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('tenofakind.com/api/... and the bare run.app path reach the same routes', async () => {
  await withServer(async (baseUrl) => {
    const direct = await fetch(`${baseUrl}/health`);
    const viaHosting = await fetch(`${baseUrl}/api/health`);
    const wallet = await fetch(`${baseUrl}/api/v1/economy/wallet`);

    assert.equal(direct.status, 200);
    assert.equal(viaHosting.status, 200);
    assert.equal((await viaHosting.json()).ok, true);
    assert.equal((await direct.json()).ok, true);
    // Reached the economy route, which wants a token.
    assert.equal(wallet.status, 401);
  });
});

test('only a whole /api path segment is treated as the public prefix', async () => {
  await withServer(async (baseUrl) => {
    assert.equal((await fetch(`${baseUrl}/apihealth`)).status, 404);
    assert.equal((await fetch(`${baseUrl}/api`)).status, 404);
    assert.equal((await fetch(`${baseUrl}/api/api/health`)).status, 404);
  });
});

test('no API answer may be cached, by the CDN or anyone else', async () => {
  await withServer(async (baseUrl) => {
    for (const path of ['/api/health', '/api/v1/economy/wallet', '/api/nope']) {
      const response = await fetch(`${baseUrl}${path}`);
      assert.equal(response.headers.get('cache-control'), 'no-store', path);
    }
  });
});
