import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { statusFor, upcoming, toICS, parseDay, daysBetween } from '../suspensions.js';

const calendar = JSON.parse(
  readFileSync(new URL('../asp-calendar.json', import.meta.url), 'utf8')
);

test('a holiday on the list reads as suspended', () => {
  const s = statusFor(parseDay('2026-11-26'), calendar);
  assert.equal(s.suspended, true);
  assert.equal(s.name, 'Thanksgiving');
});

test('an ordinary weekday is not suspended', () => {
  const s = statusFor(parseDay('2026-08-20'), calendar);
  assert.equal(s.suspended, false);
});

test('Sundays are always suspended, holiday list or not', () => {
  const sunday = parseDay('2026-08-23');
  assert.equal(sunday.getDay(), 0);
  const s = statusFor(sunday, calendar);
  assert.equal(s.suspended, true);
  assert.equal(s.routine, true);
});

test('upcoming looks forward, never back', () => {
  const next = upcoming(calendar, parseDay('2026-08-20'), 3);
  assert.deepEqual(
    next.map((s) => s.date),
    ['2026-09-07', '2026-09-12', '2026-09-13']
  );
  assert.equal(next[0].daysAway, 18);
});

test('unverified calendar surfaces that fact', () => {
  assert.equal(statusFor(parseDay('2026-11-26'), calendar).verified, false);
});

test('day arithmetic survives the DST boundary', () => {
  // US DST ends 2026-11-01; a naive millisecond diff would report 0.96 days.
  assert.equal(daysBetween(parseDay('2026-10-31'), parseDay('2026-11-02')), 2);
});

test('ICS output is well formed', () => {
  const ics = toICS(calendar, { now: parseDay('2026-08-20') });
  assert.ok(ics.startsWith('BEGIN:VCALENDAR\r\n'));
  assert.ok(ics.trimEnd().endsWith('END:VCALENDAR'));
  const begins = ics.match(/BEGIN:VEVENT/g).length;
  const ends = ics.match(/END:VEVENT/g).length;
  assert.equal(begins, calendar.suspensions.length);
  assert.equal(begins, ends);
  assert.equal(ics.match(/BEGIN:VALARM/g).length, begins);
  // every line must be CRLF-terminated and within the 75-octet fold limit
  for (const line of ics.split('\r\n')) {
    assert.ok(line.length <= 75, `line too long: ${line}`);
  }
});

test('ICS escapes commas so the SUMMARY does not split', () => {
  const ics = toICS(
    { year: 2026, verified: true, suspensions: [{ date: '2026-01-19', name: 'King, Jr. Day' }] },
    { now: parseDay('2026-08-20') }
  );
  assert.ok(ics.includes('SUMMARY:No alternate side — King\\, Jr. Day'));
});

test('all-day events end on the following day', () => {
  const ics = toICS(
    { year: 2026, verified: true, suspensions: [{ date: '2026-12-31', name: 'Test' }] },
    { now: parseDay('2026-08-20') }
  );
  assert.ok(ics.includes('DTSTART;VALUE=DATE:20261231'));
  assert.ok(ics.includes('DTEND;VALUE=DATE:20270101'), 'must roll over the year');
});
