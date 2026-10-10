const assert = require('node:assert/strict');
const http = require('node:http');
const { test } = require('node:test');

const { installGracefulShutdown } = require('../src/index');

function listen(handler) {
  const server = http.createServer(handler);
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => {
    server.port = server.address().port;
    resolve(server);
  }));
}

function request(server, path = '/') {
  const { port } = server;
  return new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path, agent: false }, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });
}

test('a running request finishes before the server exits on SIGTERM', async () => {
  const server = await listen((_req, res) => {
    setTimeout(() => res.end('settled'), 150);
  });
  const exits = [];
  const shutdown = installGracefulShutdown(server, {
    graceMs: 2000,
    exit: (code) => exits.push(code),
    bindProcessSignals: false,
  });

  const inFlight = request(server);
  await new Promise((resolve) => setTimeout(resolve, 30));
  shutdown('SIGTERM');

  assert.deepEqual(await inFlight, { status: 200, body: 'settled' });
  await new Promise((resolve) => setTimeout(resolve, 50));
  assert.deepEqual(exits, [0]);
  await assert.rejects(request(server), /ECONNREFUSED/);
});

test('a request that outlives the grace period is cut off and the server still exits', async () => {
  const server = await listen(() => { /* never answers */ });
  const exits = [];
  const shutdown = installGracefulShutdown(server, {
    graceMs: 100,
    exit: (code) => exits.push(code),
    bindProcessSignals: false,
  });

  const stuck = request(server).catch((error) => error);
  await new Promise((resolve) => setTimeout(resolve, 30));
  shutdown('SIGTERM');
  shutdown('SIGTERM'); // a second signal is ignored

  const outcome = await stuck;
  assert.ok(outcome instanceof Error);
  await new Promise((resolve) => setTimeout(resolve, 50));
  assert.deepEqual(exits, [0]);
});
