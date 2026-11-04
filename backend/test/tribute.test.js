const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  DAILY_TRIBUTE_LADDER,
  STARTER_AUP_PER_CIRCUIT,
} = require('../src/economy/constants');
const { snapshot } = require('../src/economy/progress');
const { SERVER_PROGRESS_COLLECTION } = require('../src/economy/store');
const {
  claimDailyTribute,
  localDayKey,
  nextDayKey,
  tributeAmount,
  tzOffsetMinutes,
} = require('../src/economy/tribute');
const { FakeFirestore } = require('./firestore_fake');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
// 4 Nov 2026, 10:00 in India (04:30 UTC).
const T0 = Date.parse('2026-11-04T04:30:00Z');
const IST = 330;

function claim(db, uid, nowMs, tzOffsetMinutes = IST) {
  return claimDailyTribute({ db, uid, body: { tzOffsetMinutes }, nowMs });
}

test('the ladder climbs for seven days, then pays the top step every day', () => {
  assert.equal(DAILY_TRIBUTE_LADDER.length, 7);
  for (let i = 1; i < DAILY_TRIBUTE_LADDER.length; i += 1) {
    assert.ok(DAILY_TRIBUTE_LADDER[i] > DAILY_TRIBUTE_LADDER[i - 1]);
  }
  assert.equal(tributeAmount(1), 50000);
  assert.equal(tributeAmount(7), 300000);
  assert.equal(tributeAmount(30), 300000);
  assert.equal(tributeAmount(0), 50000);
  // A week of tribute stays well under the starter for one circuit... times
  // three: a top-up, not a replacement for winning.
  const week = DAILY_TRIBUTE_LADDER.reduce((a, b) => a + b, 0);
  assert.ok(week < 3 * STARTER_AUP_PER_CIRCUIT, `${week}`);
});

test('day keys follow the player, not UTC', () => {
  // 23:30 UTC on 3 Nov is already 4 Nov in India and Vietnam.
  const late = Date.parse('2026-11-03T23:30:00Z');
  assert.equal(localDayKey(late, 0), '2026-11-03');
  assert.equal(localDayKey(late, IST), '2026-11-04');
  assert.equal(localDayKey(late, 420), '2026-11-04');
  // Brazil is behind UTC.
  assert.equal(localDayKey(Date.parse('2026-11-04T01:00:00Z'), -180), '2026-11-03');
  assert.equal(nextDayKey('2026-12-31'), '2027-01-01');
  assert.equal(nextDayKey('2028-02-28'), '2028-02-29');
  assert.equal(tzOffsetMinutes(9999), 0);
  assert.equal(tzOffsetMinutes('330'), 0);
  assert.equal(tzOffsetMinutes(-180), -180);
});

test('a new player claims day 1 into the first circuit, on top of the starter', async () => {
  const db = new FakeFirestore();
  const result = await claim(db, 'p1', T0);
  assert.equal(result.accepted, true);
  assert.equal(result.streak, 1);
  assert.equal(result.delta, 50000);
  assert.equal(result.group, 'india');
  assert.equal(result.progress.indiaAup, STARTER_AUP_PER_CIRCUIT + 50000);
  const stored = db.dump(SERVER_PROGRESS_COLLECTION, 'p1');
  assert.equal(stored.tributeStreak, 1);
  assert.equal(stored.tributeLastDayKey, '2026-11-04');
  assert.equal(stored.tributeLastAmount, 50000);
  const shown = snapshot(result.progress);
  assert.equal(shown.tributeStreak, 1);
  assert.equal(shown.tributeLastDayKey, '2026-11-04');
});

test('a second claim the same day pays nothing and says so', async () => {
  const db = new FakeFirestore();
  await claim(db, 'p2', T0);
  const again = await claim(db, 'p2', T0 + 6 * HOUR);
  assert.equal(again.accepted, false);
  assert.equal(again.duplicate, true);
  assert.equal(again.reason, 'already_claimed');
  assert.equal(again.delta, 0);
  assert.equal(again.progress.indiaAup, STARTER_AUP_PER_CIRCUIT + 50000);
});

test('consecutive days climb; a missed day starts again at day 1', async () => {
  const db = new FakeFirestore();
  const paid = [];
  for (let day = 0; day < 9; day += 1) {
    const r = await claim(db, 'p3', T0 + day * DAY);
    assert.equal(r.accepted, true, `day ${day}`);
    paid.push(r.delta);
  }
  assert.deepEqual(paid, [...DAILY_TRIBUTE_LADDER, 300000, 300000]);
  // Skip a day.
  const back = await claim(db, 'p3', T0 + 10 * DAY);
  assert.equal(back.streak, 1);
  assert.equal(back.delta, 50000);
});

test('late-night and early-morning claims on the next calendar day keep the streak', async () => {
  const db = new FakeFirestore();
  // 23:00 IST on 4 Nov, then 07:00 IST on 5 Nov: eight hours apart.
  const night = Date.parse('2026-11-04T17:30:00Z');
  await claim(db, 'p4', night);
  const morning = await claim(db, 'p4', night + 8 * HOUR);
  assert.equal(morning.accepted, true);
  assert.equal(morning.streak, 2);
});

test('changing time zone cannot pay twice within a few hours', async () => {
  const db = new FakeFirestore();
  // 23:30 UTC on 3 Nov: claim as UTC (3 Nov), then as UTC+14 (already 4 Nov).
  const t = Date.parse('2026-11-03T23:30:00Z');
  await claim(db, 'p5', t, 0);
  const hop = await claim(db, 'p5', t + 10 * 60 * 1000, 840);
  assert.equal(hop.accepted, false);
  assert.equal(hop.reason, 'too_soon');
});

test('the tribute goes to the circuit of the latest fort entry', async () => {
  const db = new FakeFirestore({
    [SERVER_PROGRESS_COLLECTION]: {
      p6: {
        legacyMigrationVersion: 1,
        starterVersion: 2,
        indiaAup: 1000,
        euroAup: 1000,
        entryReservations: [
          {
            attemptId: 'a1', campaignId: 'c1', group: 'india', amount: 0,
            status: 'settled', createdAtMs: T0 - 2 * DAY, updatedAtMs: T0 - 2 * DAY,
          },
          {
            attemptId: 'a2', campaignId: 'c2', group: 'euro', amount: 0,
            status: 'settled', createdAtMs: T0 - DAY, updatedAtMs: T0 - DAY,
          },
        ],
      },
    },
  });
  const r = await claim(db, 'p6', T0);
  assert.equal(r.group, 'euro');
  assert.equal(r.progress.euroAup, 1000 + 50000);
  assert.equal(r.progress.indiaAup, 1000);
});
