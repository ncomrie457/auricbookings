/**
 * suspensions.js — the alternate-side holiday calendar, and the .ics export
 * that turns it into real phone alerts.
 *
 * A static site cannot push you a notification while it is closed. What it
 * can do is hand your phone a calendar subscription with alarms attached,
 * which the phone then fires on its own. That is what toICS() is for.
 */

const ISO_DAY = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Parse "2026-09-21" as local noon so time zones can never shift the day. */
export function parseDay(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0);
}

/** Is alternate side suspended on this date? */
export function statusFor(date, calendar) {
  const iso = ISO_DAY(date);
  const hit = calendar.suspensions.find((s) => s.date === iso);
  if (hit) {
    return { suspended: true, name: hit.name, date: iso, verified: !!calendar.verified };
  }
  if (date.getDay() === 0) {
    return {
      suspended: true,
      name: 'Sunday',
      date: iso,
      verified: true,
      routine: true,
    };
  }
  return { suspended: false, date: iso, verified: !!calendar.verified };
}

/** The next `count` suspension days on or after `from`. */
export function upcoming(calendar, from = new Date(), count = 6) {
  const fromIso = ISO_DAY(from);
  return calendar.suspensions
    .filter((s) => s.date >= fromIso)
    .slice(0, count)
    .map((s) => ({ ...s, daysAway: daysBetween(from, parseDay(s.date)) }));
}

export function daysBetween(a, b) {
  const day = 86400000;
  const a0 = new Date(a.getFullYear(), a.getMonth(), a.getDate()).getTime();
  const b0 = new Date(b.getFullYear(), b.getMonth(), b.getDate()).getTime();
  return Math.round((b0 - a0) / day);
}

/* ------------------------------------------------------------------ *
 * iCalendar export
 * ------------------------------------------------------------------ */

function icsEscape(text) {
  return String(text)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\;')
    .replace(/,/g, '\\,')
    .replace(/\n/g, '\\n');
}

/** RFC 5545 says content lines wrap at 75 octets, continued with a leading space. */
function fold(line) {
  if (line.length <= 75) return line;
  const parts = [line.slice(0, 75)];
  let rest = line.slice(75);
  while (rest.length > 74) {
    parts.push(' ' + rest.slice(0, 74));
    rest = rest.slice(74);
  }
  if (rest) parts.push(' ' + rest);
  return parts.join('\r\n');
}

const compact = (iso) => iso.replace(/-/g, '');

/**
 * Build a subscribable calendar. Each suspension day becomes an all-day event
 * with an alarm the evening before, so the phone tells you not to bother
 * moving the car.
 *
 * @param {number} alarmHoursBefore hours before midnight to fire the alert
 */
export function toICS(calendar, { now = new Date(), alarmHoursBefore = 12 } = {}) {
  const stamp = now.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NYC Parking Signs//Alternate Side Suspensions//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:NYC alternate side suspensions ${calendar.year}`,
    'X-WR-TIMEZONE:America/New_York',
  ];

  for (const s of calendar.suspensions) {
    const start = compact(s.date);
    const end = compact(ISO_DAY(new Date(parseDay(s.date).getTime() + 86400000)));
    const caveat = calendar.verified
      ? ''
      : ' (unconfirmed — check the DOT calendar before relying on it)';
    lines.push(
      'BEGIN:VEVENT',
      `UID:asp-${s.date}@nycparkingsigns`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${start}`,
      `DTEND;VALUE=DATE:${end}`,
      `SUMMARY:${icsEscape(`No alternate side — ${s.name}`)}`,
      `DESCRIPTION:${icsEscape(
        `Alternate side parking rules are suspended for ${s.name}.${caveat} Meters and all other posted regulations still apply.`
      )}`,
      'TRANSP:TRANSPARENT',
      'BEGIN:VALARM',
      `TRIGGER:-PT${alarmHoursBefore}H`,
      'ACTION:DISPLAY',
      `DESCRIPTION:${icsEscape(`No alternate side tomorrow — ${s.name}. Leave the car where it is.`)}`,
      'END:VALARM',
      'END:VEVENT'
    );
  }

  lines.push('END:VCALENDAR');
  return lines.map(fold).join('\r\n') + '\r\n';
}
