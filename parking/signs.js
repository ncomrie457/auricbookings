/**
 * signs.js — decodes the literal text NYC DOT prints on a parking sign
 * (the `sign_description` field of the Parking Regulation Locations and
 * Signs dataset) into a structured, human-readable regulation.
 *
 * The DOT dataset gives you strings like:
 *   "NO PARKING (SANITATION BROOM SYMBOL) 11AM-12:30PM TUES & FRI"
 *   "3 HOUR METERED PARKING 8AM-7PM EXCEPT SUNDAY"
 *   "NO STANDING EXCEPT TRUCKS LOADING AND UNLOADING 7AM-6PM EXCEPT SUNDAY"
 * This module turns those into { category, days, hours, maxStay, plain }.
 *
 * No dependencies, no DOM — so it runs in the browser and under `node --test`.
 */

export const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const ALL_DAYS = [0, 1, 2, 3, 4, 5, 6];

/**
 * Regulation families, most specific first. `test` runs against the
 * normalized (uppercased, whitespace-collapsed) sign text.
 */
export const CATEGORIES = [
  {
    id: 'street-cleaning',
    label: 'Alternate side / street cleaning',
    tone: 'sweep',
    blurb: 'Move the car for the street sweeper. Suspended on the holidays in the ASP calendar.',
    test: (t) =>
      /SANITATION|BROOM|STREET CLEANING/.test(t) ||
      (/^NO PARKING/.test(t) && /ALTERNATE SIDE/.test(t)),
  },
  {
    id: 'no-stopping',
    label: 'No stopping',
    tone: 'forbid',
    blurb: 'You may not stop at all — not to wait, not to drop someone off. The strictest rule.',
    test: (t) => /NO STOPPING|DO NOT STOP/.test(t),
  },
  {
    id: 'bus-stop',
    label: 'Bus stop',
    tone: 'forbid',
    blurb: 'Bus stop. No standing or parking, and it is towed aggressively.',
    test: (t) => /BUS STOP|BUS LAYOVER|\bMTA\b/.test(t),
  },
  {
    id: 'bike-lane',
    label: 'Bike lane / bike corral',
    tone: 'forbid',
    blurb: 'Protected lane or bike parking. Standing here blocks cyclists into traffic.',
    test: (t) => /BICYCLE|BIKE LANE|BIKE CORRAL/.test(t),
  },
  {
    id: 'hydrant',
    label: 'Fire hydrant',
    tone: 'forbid',
    blurb: 'Fifteen feet either side of a hydrant, sign or no sign.',
    test: (t) => /HYDRANT|FIRE ZONE/.test(t),
  },
  {
    id: 'commercial',
    label: 'Commercial vehicles only',
    tone: 'commercial',
    blurb:
      'Reserved for commercially plated vehicles actively loading or unloading. A passenger car parked here gets a ticket even if the space is empty.',
    test: (t) =>
      /COMMERCIAL VEHICLE|TRUCKS? LOADING|LOADING AND UNLOADING|TRUCK LOADING ONLY|EXCEPT TRUCKS/.test(
        t
      ),
  },
  {
    id: 'metered',
    label: 'Metered parking',
    tone: 'meter',
    blurb: 'Pay at the muni-meter or in ParkNYC. The hour figure is the maximum stay, not a suggestion.',
    test: (t) => /METER|MUNI-?METER/.test(t),
  },
  {
    id: 'permit',
    label: 'Permit / authorized vehicles only',
    tone: 'forbid',
    blurb: 'Agency, consulate, press, or building permit holders only.',
    test: (t) =>
      /AUTHORIZED VEHICLES|PERMIT|CONSULATE|DIPLOMAT|POLICE|PRESS|OFFICIAL/.test(t),
  },
  {
    id: 'accessible',
    label: 'Accessible parking',
    tone: 'info',
    blurb: 'Reserved for vehicles displaying a valid NYC or NY State permit.',
    test: (t) => /HANDICAP|DISABILITY|ACCESSIBLE|WHEELCHAIR/.test(t),
  },
  {
    id: 'taxi',
    label: 'Taxi / for-hire stand',
    tone: 'forbid',
    blurb: 'Taxi stand or for-hire pickup zone.',
    test: (t) => /TAXI|FOR HIRE|CAR SERVICE/.test(t),
  },
  {
    id: 'carshare',
    label: 'Car share',
    tone: 'info',
    blurb: 'Dedicated car-share space (Zipcar and similar) under the DOT car-share program.',
    test: (t) => /CAR SHARE|CARSHARE/.test(t),
  },
  {
    id: 'school',
    label: 'School zone',
    tone: 'info',
    blurb: 'School-hours restriction — usually no parking while school is in session.',
    test: (t) => /SCHOOL/.test(t),
  },
  {
    id: 'no-standing',
    label: 'No standing',
    tone: 'forbid',
    blurb: 'You may drop off or pick up passengers, but you may not wait and you may not load goods.',
    test: (t) => /NO STANDING/.test(t),
  },
  {
    id: 'time-limited',
    label: 'Time-limited parking',
    tone: 'limit',
    blurb: 'Free, but only for the posted stretch of time. Moving up a few feet does not reset it.',
    test: (t) => /\d+\s*(HOUR|HR|MINUTE|MIN)\b/.test(t) && !/NO PARKING|NO STANDING/.test(t),
  },
  {
    id: 'no-parking',
    label: 'No parking',
    tone: 'forbid',
    blurb: 'You may stop briefly to load or unload goods or passengers, but you may not park.',
    test: (t) => /NO PARKING/.test(t),
  },
  {
    id: 'other',
    label: 'Other regulation',
    tone: 'info',
    blurb: 'Something outside the common families — read the sign text itself.',
    test: () => true,
  },
];

const DAY_WORDS = [
  [/\bSUN(DAY)?S?\b/, 0],
  [/\bMON(DAY)?S?\b/, 1],
  [/\bTUES?(DAY)?S?\b/, 2],
  [/\bWED(NESDAY)?S?\b/, 3],
  [/\bTHURS?(DAY)?S?\b/, 4],
  [/\bFRI(DAY)?S?\b/, 5],
  [/\bSAT(URDAY)?S?\b/, 6],
];

export function normalize(text) {
  return String(text || '')
    .toUpperCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/** "8AM" / "12:30PM" / "NOON" / "MIDNIGHT" -> minutes past midnight */
function toMinutes(hour, minute, meridiem, fallbackMeridiem) {
  let h = Number(hour);
  const m = Number(minute || 0);
  const mer = meridiem || fallbackMeridiem;
  if (mer === 'PM' && h !== 12) h += 12;
  if (mer === 'AM' && h === 12) h = 0;
  return h * 60 + m;
}

const TIME = '(\\d{1,2})(?::(\\d{2}))?\\s*(AM|PM|NOON|MIDNIGHT)?';
const RANGE_RE = new RegExp(`${TIME}\\s*(?:-|–|\\s+TO\\s+|\\s+THRU\\s+)\\s*${TIME}`, 'g');

/** Pull every time window out of a sign, e.g. "7AM-10AM 4PM-7PM" -> two windows. */
export function parseHours(text) {
  const t = normalize(text)
    .replace(/\bNOON\b/g, '12PM')
    .replace(/\bMIDNIGHT\b/g, '12AM');
  const out = [];
  RANGE_RE.lastIndex = 0;
  let m;
  while ((m = RANGE_RE.exec(t)) !== null) {
    const [, h1, m1, mer1, h2, m2, mer2] = m;
    // "8-11AM": the first half borrows the meridiem of the second.
    const start = toMinutes(h1, m1, mer1, mer2);
    let end = toMinutes(h2, m2, mer2, mer1);
    if (end === start) continue;
    out.push({ start, end, wraps: end < start });
  }
  return out;
}

/** Which days of the week the regulation runs on. */
export function parseDays(text) {
  const t = normalize(text);

  const EXCEPT_WEEKEND = /EXCEPT\s+SAT[A-Z]*\s*(?:,|&|AND)\s*SUN[A-Z]*/;
  const EXCEPT_SUNDAY = /EXCEPT\s+SUN[A-Z]*/;
  const INCLUDING_SUNDAY = /INCLUDING\s+SUN[A-Z]*/;

  let excluded = [];
  if (EXCEPT_WEEKEND.test(t)) excluded = [0, 6];
  else if (EXCEPT_SUNDAY.test(t)) excluded = [0];
  const including = INCLUDING_SUNDAY.test(t);

  // Strip the except/including phrases before hunting for listed days, or
  // "9AM-7PM INCLUDING SUNDAY" reads as "Sundays only".
  const scan = t
    .replace(EXCEPT_WEEKEND, ' ')
    .replace(EXCEPT_SUNDAY, ' ')
    .replace(INCLUDING_SUNDAY, ' ');

  // "MON THRU FRI" / "MONDAY THROUGH SATURDAY"
  const span = scan.match(
    /\b(SUN|MON|TUES?|WED|THURS?|FRI|SAT)[A-Z]*\s*(?:-|THRU|THROUGH)\s*(SUN|MON|TUES?|WED|THURS?|FRI|SAT)[A-Z]*/
  );
  if (span) {
    const a = dayIndex(span[1]);
    const b = dayIndex(span[2]);
    if (a !== -1 && b !== -1) {
      const days = [];
      for (let i = a; days.length <= 7; i = (i + 1) % 7) {
        days.push(i);
        if (i === b) break;
      }
      return { days, source: 'span' };
    }
  }

  // Explicitly listed days: "TUES & FRI", "MON, WED & FRI"
  const listed = [];
  for (const [re, idx] of DAY_WORDS) {
    if (re.test(scan)) listed.push(idx);
  }
  if (listed.length) return { days: listed.sort((a, b) => a - b), source: 'listed' };

  if (excluded.length) {
    const days = ALL_DAYS.filter((d) => !excluded.includes(d));
    return { days, source: excluded.length === 2 ? 'weekdays' : 'except-sunday' };
  }
  if (including) return { days: ALL_DAYS.slice(), source: 'including-sunday' };
  return { days: ALL_DAYS.slice(), source: 'default' };
}

function dayIndex(token) {
  for (const [re, idx] of DAY_WORDS) if (re.test(token)) return idx;
  return -1;
}

/** Maximum stay in minutes, if the sign posts one. */
export function parseMaxStay(text) {
  const t = normalize(text);
  const half = t.match(/1\/2\s*HOUR/);
  if (half) return 30;
  const mins = t.match(/(\d+)\s*(?:MINUTE|MIN)\b/);
  if (mins) return Number(mins[1]);
  const hrs = t.match(/(\d+)\s*(?:HOUR|HR)\b/);
  if (hrs) return Number(hrs[1]) * 60;
  return null;
}

export function classify(description) {
  const raw = String(description || '');
  const t = normalize(raw);
  const category = CATEGORIES.find((c) => c.test(t)) || CATEGORIES[CATEGORIES.length - 1];
  const hours = parseHours(t);
  const { days, source: daySource } = parseDays(t);
  const maxStay = parseMaxStay(t);
  const anyTime = /ANYTIME|ANY TIME/.test(t);

  return {
    raw,
    text: t,
    category: category.id,
    label: category.label,
    tone: category.tone,
    blurb: category.blurb,
    hours,
    days,
    daySource,
    maxStay,
    anyTime,
    plain: describe({ category: category.id, label: category.label, hours, days, daySource, maxStay, anyTime }),
  };
}

function fmtTime(mins) {
  const h24 = Math.floor(mins / 60) % 24;
  const m = mins % 60;
  const mer = h24 >= 12 ? 'pm' : 'am';
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  return m ? `${h}:${String(m).padStart(2, '0')}${mer}` : `${h}${mer}`;
}

export function fmtDays(days, source) {
  if (source === 'default' || days.length === 7) return 'every day';
  if (source === 'except-sunday') return 'Mon–Sat';
  if (days.length === 5 && days.join() === '1,2,3,4,5') return 'weekdays';
  if (days.length === 2 && days.join() === '0,6') return 'weekends';
  const names = days.map((d) => DAYS[d]);
  if (names.length === 1) return names[0];
  return `${names.slice(0, -1).join(', ')} & ${names[names.length - 1]}`;
}

function describe(r) {
  const when = r.hours.length
    ? `${r.hours.map((h) => `${fmtTime(h.start)}–${fmtTime(h.end)}`).join(' and ')}, ${fmtDays(r.days, r.daySource)}`
    : r.anyTime
      ? 'at all times'
      : fmtDays(r.days, r.daySource);
  const stay = r.maxStay
    ? r.maxStay >= 60
      ? `up to ${r.maxStay / 60} hour${r.maxStay === 60 ? '' : 's'}`
      : `up to ${r.maxStay} minutes`
    : null;

  switch (r.category) {
    case 'street-cleaning':
      return `Move your car ${when} for the sweeper.`;
    case 'metered':
      return `Pay the meter ${when}${stay ? `, ${stay}` : ''}. Free outside those hours unless another sign says otherwise.`;
    case 'commercial':
      return `Commercial plates only ${when}. Passenger cars are ticketed here.`;
    case 'time-limited':
      return `Free parking ${stay ? stay : ''} ${when}.`.replace(/\s+/g, ' ').trim();
    case 'no-standing':
      return `No standing ${when} — dropping off is fine, waiting is not.`;
    case 'no-stopping':
      return `No stopping ${when}, for any reason.`;
    case 'no-parking':
      return `No parking ${when} — brief loading only.`;
    default:
      return `${r.label} ${when}.`;
  }
}

/**
 * Is this regulation in force at `date`? Handles windows that cross midnight.
 */
export function isActiveAt(reg, date = new Date()) {
  const day = date.getDay();
  const mins = date.getHours() * 60 + date.getMinutes();
  if (!reg.hours.length) return reg.days.includes(day);
  for (const h of reg.hours) {
    if (h.wraps) {
      // e.g. 10pm–6am: active late on the listed day, and early the next morning
      if (reg.days.includes(day) && mins >= h.start) return true;
      if (reg.days.includes((day + 6) % 7) && mins < h.end) return true;
    } else if (reg.days.includes(day) && mins >= h.start && mins < h.end) {
      return true;
    }
  }
  return false;
}
