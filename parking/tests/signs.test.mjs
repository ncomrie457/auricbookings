import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classify, parseDays, parseHours, parseMaxStay, isActiveAt } from '../signs.js';

const at = (dayIdx, h, m = 0) => {
  // 2026-08-16 is a Sunday, so +dayIdx lands on the weekday we want.
  const d = new Date(2026, 7, 16 + dayIdx, h, m);
  assert.equal(d.getDay(), dayIdx);
  return d;
};

test('alternate side / street cleaning', () => {
  const r = classify('NO PARKING (SANITATION BROOM SYMBOL) 11AM-12:30PM TUES & FRI');
  assert.equal(r.category, 'street-cleaning');
  assert.deepEqual(r.days, [2, 5]);
  assert.deepEqual(r.hours, [{ start: 660, end: 750, wraps: false }]);
  assert.ok(isActiveAt(r, at(2, 11, 30)));
  assert.ok(!isActiveAt(r, at(2, 13, 0)));
  assert.ok(!isActiveAt(r, at(3, 11, 30)));
});

test('metered parking keeps its hour limit', () => {
  const r = classify('3 HOUR METERED PARKING 8AM-7PM EXCEPT SUNDAY');
  assert.equal(r.category, 'metered');
  assert.equal(r.maxStay, 180);
  assert.deepEqual(r.days, [1, 2, 3, 4, 5, 6]);
  assert.ok(isActiveAt(r, at(1, 9)));
  assert.ok(!isActiveAt(r, at(0, 9)), 'Sunday is excepted');
});

test('five hour metered parking', () => {
  const r = classify('5 HOUR METERED PARKING 7AM-10PM INCLUDING SUNDAY');
  assert.equal(r.category, 'metered');
  assert.equal(r.maxStay, 300);
  assert.deepEqual(r.days, [0, 1, 2, 3, 4, 5, 6], 'INCLUDING SUNDAY means all week');
});

test('commercial vehicles only', () => {
  const r = classify('NO STANDING EXCEPT TRUCKS LOADING AND UNLOADING 7AM-6PM MON THRU FRI');
  assert.equal(r.category, 'commercial');
  assert.deepEqual(r.days, [1, 2, 3, 4, 5]);
  assert.match(r.plain, /Commercial plates only/);
});

test('commercial metered zone still reads as commercial', () => {
  const r = classify('COMMERCIAL VEHICLES ONLY 3 HOUR METERED PARKING 7AM-7PM EXCEPT SUNDAY');
  assert.equal(r.category, 'commercial');
  assert.equal(r.maxStay, 180);
});

test('no parking anytime', () => {
  const r = classify('NO PARKING ANYTIME');
  assert.equal(r.category, 'no-parking');
  assert.equal(r.anyTime, true);
  assert.deepEqual(r.hours, []);
  assert.ok(isActiveAt(r, at(3, 3)));
});

test('overnight window wraps past midnight', () => {
  const r = classify('NO STANDING 10PM-6AM');
  assert.deepEqual(r.hours, [{ start: 1320, end: 360, wraps: true }]);
  assert.ok(isActiveAt(r, at(3, 23)), 'late Wednesday');
  assert.ok(isActiveAt(r, at(4, 2)), 'early Thursday is still the Wednesday window');
  assert.ok(!isActiveAt(r, at(3, 12)));
});

test('two rush-hour windows on one sign', () => {
  const r = classify('NO STANDING 7AM-10AM 4PM-7PM MON THRU FRI');
  assert.equal(r.hours.length, 2);
  assert.ok(isActiveAt(r, at(1, 8)));
  assert.ok(!isActiveAt(r, at(1, 12)));
  assert.ok(isActiveAt(r, at(1, 17)));
});

test('shared meridiem: "8-11AM"', () => {
  assert.deepEqual(parseHours('NO PARKING 8-11AM'), [{ start: 480, end: 660, wraps: false }]);
});

test('noon and midnight', () => {
  assert.deepEqual(parseHours('NO PARKING MIDNIGHT TO NOON'), [
    { start: 0, end: 720, wraps: false },
  ]);
});

test('half hour and minute limits', () => {
  assert.equal(parseMaxStay('1/2 HOUR PARKING 9AM-6PM'), 30);
  assert.equal(parseMaxStay('20 MINUTE PARKING'), 20);
  assert.equal(parseMaxStay('1 HOUR PARKING'), 60);
  assert.equal(parseMaxStay('NO PARKING ANYTIME'), null);
});

test('except Saturday and Sunday means weekdays', () => {
  assert.deepEqual(parseDays('7AM-7PM EXCEPT SATURDAY AND SUNDAY').days, [1, 2, 3, 4, 5]);
});

test('bus stop beats the generic no-standing rule', () => {
  assert.equal(classify('BUS STOP NO STANDING').category, 'bus-stop');
});

test('unparseable text still classifies without throwing', () => {
  const r = classify('');
  assert.equal(r.category, 'other');
  assert.ok(typeof r.plain === 'string');
});
