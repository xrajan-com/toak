const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  _asHttpsUrl,
  _shapeAppRelease,
} = require('../src/routes/app_release');

test('a well-formed release document passes through intact', () => {
  assert.deepEqual(
    _shapeAppRelease({
      latestBuild: 84,
      message: 'A new version of X Poker is available.',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.toak',
    }),
    {
      latestBuild: 84,
      message: 'A new version of X Poker is available.',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.toak',
    },
  );
});

test('a build number typed as a string in the console still counts', () => {
  assert.equal(_shapeAppRelease({ latestBuild: '84' }).latestBuild, 84);
});

test('a missing or malformed document yields nulls, never a throw', () => {
  for (const input of [null, undefined, 'nonsense', 42, []]) {
    assert.deepEqual(_shapeAppRelease(input), {
      latestBuild: null,
      message: null,
      storeUrl: null,
    });
  }
});

test('junk build numbers are dropped rather than shipped to clients', () => {
  for (const bad of [0, -3, 1.5e300, 'v84', '', '  ', {}, null, NaN, Infinity]) {
    assert.equal(
      _shapeAppRelease({ latestBuild: bad }).latestBuild,
      null,
      `expected ${JSON.stringify(bad)} to be rejected`,
    );
  }
});

test('a float build number truncates instead of reaching the client as a float', () => {
  assert.equal(_shapeAppRelease({ latestBuild: 84.9 }).latestBuild, 84);
});

test('only https store links survive', () => {
  assert.equal(_asHttpsUrl('https://example.com/app'), 'https://example.com/app');
  for (const bad of [
    'http://example.com/app',
    'javascript:alert(1)',
    'market://details?id=com.toak',
    'intent://scan#Intent;scheme=zxing;end',
    'data:text/html,<script>alert(1)</script>',
    'not a url',
    '',
    null,
    17,
  ]) {
    assert.equal(_asHttpsUrl(bad), null, `expected ${String(bad)} to be rejected`);
  }
});

test('an over-long message is truncated, not rejected wholesale', () => {
  const shaped = _shapeAppRelease({ message: 'x'.repeat(1000) });
  assert.equal(shaped.message.length, 240);
});

test('a blank message reads as absent so the client shows its own copy', () => {
  assert.equal(_shapeAppRelease({ message: '   ' }).message, null);
});
