import { classify, isActiveAt } from './signs.js';
import {
  fetchSignsNear,
  fetchSignsOnStreet,
  fetchEventsOnStreet,
  groupIntoBlocks,
  SocrataError,
} from './nycdata.js';
import { statusFor, upcoming, toICS, parseDay, daysBetween } from './suspensions.js';
import { GUIDE, RULES_OF_THUMB } from './guide.js';

const $ = (sel) => document.querySelector(sel);
const el = (tag, className) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  return node;
};

const esc = (text) =>
  String(text ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
  );

const titleCase = (text) =>
  String(text || '')
    .toLowerCase()
    .replace(/\b([a-z])/g, (m) => m.toUpperCase())
    .replace(/\b(Ave|St|Rd|Blvd|Pl|Ln|Dr|Ct|Pkwy|Hwy)\b/g, (m) => m);

const BOROUGHS = { M: 'Manhattan', B: 'Bronx', X: 'Bronx', K: 'Brooklyn', Q: 'Queens', S: 'Staten Island', R: 'Staten Island' };
const boroughName = (code) => {
  const raw = String(code || '').trim();
  if (!raw) return '';
  if (raw.length === 1) return BOROUGHS[raw.toUpperCase()] || raw;
  return titleCase(raw);
};

let calendar = null;

/* ==================================================================== *
 * Tabs
 * ==================================================================== */
for (const tab of document.querySelectorAll('.tab')) {
  tab.addEventListener('click', () => {
    for (const other of document.querySelectorAll('.tab')) {
      const on = other === tab;
      other.setAttribute('aria-selected', String(on));
      $(`#panel-${other.dataset.panel}`).hidden = !on;
    }
  });
}

/* ==================================================================== *
 * Status helpers
 * ==================================================================== */
function setStatus(node, message, kind = 'busy') {
  if (!message) {
    node.hidden = true;
    node.textContent = '';
    return;
  }
  node.hidden = false;
  node.className = `status ${kind}`;
  node.textContent = message;
}

function reportError(node, error) {
  if (error instanceof SocrataError) {
    setStatus(node, error.message, 'error');
  } else {
    setStatus(node, `Something went wrong: ${error.message}`, 'error');
  }
  console.error(error);
}

/* ==================================================================== *
 * Watched blocks — the "tell me when a sign changes" half
 * ==================================================================== */
const WATCH_KEY = 'nycparking.watched.v1';

const readWatched = () => {
  try {
    return JSON.parse(localStorage.getItem(WATCH_KEY) || '{}');
  } catch {
    return {};
  }
};
const writeWatched = (data) => {
  try {
    localStorage.setItem(WATCH_KEY, JSON.stringify(data));
  } catch {
    /* private browsing — watching just won't persist */
  }
};

/** A stable identity for one sign, so we can diff today's list against last week's. */
const signature = (row) =>
  [row.order_number, row.sign_description, row.distance_from_intersection]
    .map((v) => String(v ?? '').trim())
    .join('|');

const fingerprint = (signs) => signs.map(signature).sort();

function isWatched(key) {
  return Object.prototype.hasOwnProperty.call(readWatched(), key);
}

function toggleWatch(block) {
  const watched = readWatched();
  if (watched[block.key]) {
    delete watched[block.key];
  } else {
    watched[block.key] = {
      key: block.key,
      borough: block.borough,
      onStreet: block.onStreet,
      fromStreet: block.fromStreet,
      toStreet: block.toStreet,
      side: block.side,
      fingerprint: fingerprint(block.signs),
      checkedAt: new Date().toISOString(),
      pending: null,
    };
  }
  writeWatched(watched);
}

/** Re-query every watched block and flag anything DOT has added or removed. */
async function refreshWatched() {
  const watched = readWatched();
  const keys = Object.keys(watched);
  const host = $('#watchlist');
  const list = $('#watchlist-items');
  if (!keys.length) {
    host.hidden = true;
    return;
  }
  host.hidden = false;
  list.textContent = 'Checking DOT for changes…';

  const byStreet = new Map();
  for (const key of keys) {
    const entry = watched[key];
    if (!byStreet.has(entry.onStreet)) byStreet.set(entry.onStreet, []);
    byStreet.get(entry.onStreet).push(entry);
  }

  for (const [street, entries] of byStreet) {
    try {
      const blocks = groupIntoBlocks(await fetchSignsOnStreet(street));
      for (const entry of entries) {
        const block = blocks.find((b) => b.key === entry.key);
        if (!block) continue;
        const now = fingerprint(block.signs);
        const before = entry.fingerprint || [];
        const added = now.filter((s) => !before.includes(s));
        const removed = before.filter((s) => !now.includes(s));
        if (added.length || removed.length) {
          entry.pending = { added, removed, at: new Date().toISOString() };
          notify(
            `Sign change on ${titleCase(entry.onStreet)}`,
            `${added.length} new, ${removed.length} removed since you last looked.`
          );
        }
        entry.fingerprint = now;
        entry.checkedAt = new Date().toISOString();
        entry.cache = block;
      }
    } catch (error) {
      console.warn(`Could not refresh ${street}:`, error);
    }
  }

  writeWatched(watched);
  renderWatchlist();
}

function renderWatchlist() {
  const watched = readWatched();
  const entries = Object.values(watched);
  const host = $('#watchlist');
  const list = $('#watchlist-items');
  list.textContent = '';
  if (!entries.length) {
    host.hidden = true;
    return;
  }
  host.hidden = false;

  for (const entry of entries) {
    const card = el('div', 'card');
    const changed = entry.pending && (entry.pending.added.length || entry.pending.removed.length);
    card.innerHTML = `
      <h3 style="margin:0 0 4px;font-size:1rem">${esc(blockTitle(entry))}</h3>
      <p class="hint" style="margin:0">${esc(blockSubtitle(entry))} · last checked ${esc(
        relativeTime(entry.checkedAt)
      )}</p>`;

    if (changed) {
      const flag = el('div', 'warn');
      flag.innerHTML = `<strong>DOT changed this block.</strong> ${entry.pending.added.length} sign(s) added, ${entry.pending.removed.length} removed.`;
      const added = entry.pending.added
        .map((s) => s.split('|')[1])
        .filter(Boolean);
      if (added.length) {
        const ul = el('ul');
        ul.style.margin = '6px 0 0';
        ul.style.paddingLeft = '18px';
        for (const text of added) {
          const li = el('li');
          li.textContent = text;
          ul.append(li);
        }
        flag.append(ul);
      }
      const ok = el('button', 'btn');
      ok.style.marginTop = '10px';
      ok.textContent = 'Got it';
      ok.addEventListener('click', () => {
        const data = readWatched();
        if (data[entry.key]) data[entry.key].pending = null;
        writeWatched(data);
        renderWatchlist();
      });
      flag.append(ok);
      card.append(flag);
    }

    if (entry.cache) card.append(renderSignList(entry.cache));

    const stop = el('button', 'watch-btn on');
    stop.style.marginTop = '12px';
    stop.textContent = 'Stop watching';
    stop.addEventListener('click', () => {
      const data = readWatched();
      delete data[entry.key];
      writeWatched(data);
      renderWatchlist();
    });
    card.append(stop);
    list.append(card);
  }
}

function relativeTime(iso) {
  if (!iso) return 'never';
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.round(diff / 60000);
  if (mins < 2) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.round(hrs / 24)}d ago`;
}

/* ==================================================================== *
 * Rendering blocks
 * ==================================================================== */
const blockTitle = (block) =>
  `${titleCase(block.onStreet)} between ${titleCase(block.fromStreet)} and ${titleCase(block.toStreet)}`;

function blockSubtitle(block) {
  const bits = [];
  const side = String(block.side || '').trim();
  if (side) bits.push(`${titleCase(side)} side`);
  const boro = boroughName(block.borough);
  if (boro) bits.push(boro);
  if (Number.isFinite(block.nearestFt) && block.nearestFt !== Infinity) {
    bits.push(`${Math.round(block.nearestFt)} ft away`);
  }
  // A live block carries its rows; a stored watch entry only carries the
  // fingerprint it was saved with.
  const count = block.signs?.length ?? block.fingerprint?.length ?? 0;
  if (count) bits.push(`${count} sign${count === 1 ? '' : 's'}`);
  return bits.join(' · ');
}

function renderSignList(block, { now = new Date() } = {}) {
  const frag = document.createDocumentFragment();
  const seen = new Set();

  for (const row of block.signs) {
    const text = String(row.sign_description || '').trim();
    if (!text) continue;
    const dedupe = `${text}|${row.distance_from_intersection}`;
    if (seen.has(dedupe)) continue;
    seen.add(dedupe);

    const reg = classify(text);
    const active = isActiveAt(reg, now);

    const node = el('div', 'sign');
    node.dataset.tone = reg.tone;

    const bar = el('div', 'sign-bar');
    const body = el('div');

    const label = el('div', 'sign-label');
    label.textContent = reg.label;
    if (active) {
      const pill = el('span', 'pill active');
      pill.textContent = 'in force now';
      label.append(pill);
    }

    const plain = el('p', 'sign-plain');
    plain.textContent = reg.plain;

    const raw = el('p', 'sign-raw');
    raw.textContent = text;

    body.append(label, plain, raw);

    const where = [];
    if (row.distance_from_intersection) {
      where.push(`${row.distance_from_intersection} ft from ${titleCase(block.fromStreet)}`);
    }
    if (row.arrow_direction) where.push(`arrow: ${row.arrow_direction}`);
    if (row.sign_location) where.push(String(row.sign_location).toLowerCase());
    if (where.length) {
      const w = el('p', 'sign-where');
      w.textContent = where.join(' · ');
      body.append(w);
    }

    node.append(bar, body);
    frag.append(node);
  }

  if (!seen.size) {
    const empty = el('p', 'empty');
    empty.textContent = 'DOT lists sign orders here but no readable sign text.';
    frag.append(empty);
  }
  return frag;
}

function renderBlock(block) {
  const card = el('article', 'block');

  const head = el('div', 'block-head');
  const heading = el('div');
  const h = el('h3', 'block-title');
  h.textContent = blockTitle(block);
  const sub = el('p', 'block-sub');
  sub.textContent = blockSubtitle(block);
  heading.append(h, sub);

  const watch = el('button', 'watch-btn');
  const paint = () => {
    const on = isWatched(block.key);
    watch.classList.toggle('on', on);
    watch.textContent = on ? '★ Watching' : '☆ Watch';
    watch.setAttribute('aria-pressed', String(on));
  };
  paint();
  watch.addEventListener('click', () => {
    toggleWatch(block);
    paint();
    renderWatchlist();
  });

  head.append(heading, watch);
  card.append(head, renderSignList(block));
  return card;
}

function renderBlocks(host, blocks, { limit = 12 } = {}) {
  host.textContent = '';
  if (!blocks.length) {
    const empty = el('p', 'empty');
    empty.textContent = 'No current sign orders found here.';
    host.append(empty);
    return;
  }
  for (const block of blocks.slice(0, limit)) host.append(renderBlock(block));
  if (blocks.length > limit) {
    const more = el('p', 'empty');
    more.textContent = `${blocks.length - limit} more block faces not shown.`;
    host.append(more);
  }
}

/* ==================================================================== *
 * Near me
 * ==================================================================== */
$('#locate').addEventListener('click', () => {
  const status = $('#near-status');
  const results = $('#near-results');
  if (!navigator.geolocation) {
    setStatus(status, 'This browser has no location support. Use "Find a block" instead.', 'error');
    return;
  }
  setStatus(status, 'Getting your location…');
  navigator.geolocation.getCurrentPosition(
    async (pos) => {
      const radius = Number($('#radius').value);
      setStatus(status, 'Asking DOT what is posted around you…');
      try {
        const rows = await fetchSignsNear(pos.coords.latitude, pos.coords.longitude, {
          radiusFt: radius,
        });
        const blocks = groupIntoBlocks(rows).sort((a, b) => a.nearestFt - b.nearestFt);
        if (!blocks.length) {
          setStatus(
            status,
            `No signs on file within ${radius} ft. Try a wider radius — DOT does not have a coordinate for every sign.`,
            'busy'
          );
        } else {
          setStatus(
            status,
            `${rows.length} signs across ${blocks.length} block faces, nearest first.`,
            'busy'
          );
        }
        renderBlocks(results, blocks);
      } catch (error) {
        reportError(status, error);
      }
    },
    (error) => {
      const messages = {
        1: 'Location permission denied. Use "Find a block" to search by street name instead.',
        2: 'Your position is unavailable right now.',
        3: 'Timed out getting your location.',
      };
      setStatus(status, messages[error.code] || error.message, 'error');
    },
    { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
  );
});

/* ==================================================================== *
 * Find a block
 * ==================================================================== */
$('#street-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const street = $('#street-input').value.trim();
  const status = $('#block-status');
  const picker = $('#block-picker');
  const results = $('#block-results');
  results.textContent = '';
  picker.hidden = true;
  if (street.length < 3) {
    setStatus(status, 'Give it at least three characters.', 'error');
    return;
  }

  setStatus(status, `Searching DOT sign orders on ${street}…`);
  try {
    const rows = await fetchSignsOnStreet(street);
    const blocks = groupIntoBlocks(rows).sort((a, b) =>
      blockTitle(a).localeCompare(blockTitle(b))
    );
    if (!blocks.length) {
      setStatus(
        status,
        `Nothing on file for "${street}". DOT abbreviates — try "Ave" not "Avenue", or "West 44 Street".`,
        'error'
      );
      return;
    }
    setStatus(status, `${blocks.length} block faces on ${titleCase(street)}. Pick one.`, 'busy');

    picker.hidden = false;
    picker.textContent = '';
    const heading = el('h2');
    heading.textContent = 'Which block?';
    const list = el('div', 'picker-list');
    for (const block of blocks.slice(0, 60)) {
      const button = el('button', 'picker-item');
      button.innerHTML = `${esc(blockTitle(block))}<br><span class="count">${esc(
        blockSubtitle(block)
      )}</span>`;
      button.addEventListener('click', () => {
        renderBlocks(results, [block]);
        results.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
      list.append(button);
    }
    picker.append(heading, list);
    if (blocks.length > 60) {
      const note = el('p', 'empty');
      note.textContent = `${blocks.length - 60} more — narrow the street name to see them.`;
      picker.append(note);
    }
  } catch (error) {
    reportError(status, error);
  }
});

/* ==================================================================== *
 * Sign guide
 * ==================================================================== */
function renderGuide() {
  const host = $('#guide-body');
  const toneOf = Object.fromEntries(
    GUIDE.map((entry) => [entry.id, classify(entry.examples[0] || '').tone])
  );

  for (const entry of GUIDE) {
    const card = el('div', 'card');
    const wrap = el('div', 'guide-entry');
    wrap.dataset.tone = toneOf[entry.id] || 'info';
    const h = el('h3');
    h.textContent = entry.heading;
    const body = el('p');
    body.textContent = entry.body;
    wrap.append(h, body);
    for (const example of entry.examples) {
      const ex = el('div', 'example');
      ex.textContent = example;
      wrap.append(ex);
    }
    const gotcha = el('p', 'gotcha');
    gotcha.innerHTML = `<strong>Watch out:</strong> ${esc(entry.gotcha)}`;
    wrap.append(gotcha);
    card.append(wrap);
    host.append(card);
  }

  const rules = el('div', 'card');
  const h = el('h2');
  h.textContent = 'Reading a pole with several signs';
  rules.append(h);
  const ul = el('ul');
  ul.style.paddingLeft = '18px';
  ul.style.fontSize = '.93rem';
  for (const rule of RULES_OF_THUMB) {
    const li = el('li');
    li.textContent = rule;
    li.style.marginBottom = '8px';
    ul.append(li);
  }
  rules.append(ul);
  host.append(rules);
}

/* ==================================================================== *
 * Suspensions
 * ==================================================================== */
function renderSuspensions() {
  const today = new Date();
  const status = statusFor(today, calendar);
  const tomorrow = statusFor(new Date(today.getTime() + 86400000), calendar);

  const head = $('#susp-today');
  head.innerHTML = `
    <h2>${status.suspended ? 'Alternate side is suspended today' : 'Alternate side is in effect today'}</h2>
    <p>${
      status.suspended
        ? `${esc(status.name)}${status.routine ? '' : ' — a holiday on the DOT calendar'}. Meters and every other posted rule still apply.`
        : 'No holiday suspension on file for today. Check the sign on your block for its sweeping window.'
    }</p>
    <p style="margin-bottom:0"><strong>Tomorrow:</strong> ${
      tomorrow.suspended ? `suspended — ${esc(tomorrow.name)}` : 'in effect'
    }</p>`;

  if (!calendar.verified) {
    const warn = el('div', 'warn');
    warn.innerHTML = `<strong>This calendar is not yet verified.</strong> It was compiled from press reporting of DOT's ${calendar.year} calendar rather than read off the source. Check it against <a href="${esc(
      calendar.verifyAgainst
    )}">DOT's official PDF</a> before trusting a date, and see the README for how to correct the file.`;
    head.append(warn);
  }

  const strip = $('#now-strip');
  strip.hidden = false;
  strip.classList.toggle('is-suspended', status.suspended);
  strip.innerHTML = status.suspended
    ? `<strong>Today: alternate side suspended</strong> (${esc(status.name)}). Meters still run.`
    : `<strong>Today: alternate side in effect.</strong>${
        tomorrow.suspended ? ` Suspended tomorrow — ${esc(tomorrow.name)}.` : ''
      }`;

  const list = $('#susp-list');
  list.innerHTML = '<h2>Coming up</h2>';
  const next = upcoming(calendar, today, 10);
  if (!next.length) {
    const empty = el('p', 'empty');
    empty.textContent = `No dates left in the ${calendar.year} calendar. Next year's file needs to be added.`;
    list.append(empty);
  }
  for (const entry of next) {
    const row = el('div', 'susp-row');
    const when = parseDay(entry.date);
    const away = entry.daysAway;
    row.innerHTML = `<span>${esc(entry.name)}</span><span class="susp-date">${when.toLocaleDateString(
      'en-US',
      { weekday: 'short', month: 'short', day: 'numeric' }
    )}${away === 0 ? ' · today' : away === 1 ? ' · tomorrow' : ` · in ${away} days`}</span>`;
    list.append(row);
  }

  const gaps = el('p', 'hint');
  gaps.style.marginTop = '14px';
  gaps.textContent =
    'Weather and emergency suspensions are announced the same morning and are never on this list — 311 or @NYCASP has those.';
  list.append(gaps);
}

$('#ics').addEventListener('click', () => {
  const blob = new Blob([toICS(calendar)], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = el('a');
  link.href = url;
  link.download = `nyc-alternate-side-${calendar.year}.ics`;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});

function notify(title, body) {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  try {
    new Notification(title, { body, icon: 'icon.svg' });
  } catch {
    /* some browsers only allow notifications from a service worker */
  }
}

$('#notify').addEventListener('click', async () => {
  const hint = $('#notify-hint');
  if (!('Notification' in window)) {
    hint.textContent = 'This browser has no notification support.';
    return;
  }
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    hint.textContent = 'Notifications were not allowed.';
    return;
  }
  hint.textContent =
    'Enabled. You will get an alert when a watched block changes or a suspension is a day out — but only while this page is open, which is why the calendar file above is the reliable one.';
  const tomorrow = statusFor(new Date(Date.now() + 86400000), calendar);
  if (tomorrow.suspended && !tomorrow.routine) {
    notify('No alternate side tomorrow', `${tomorrow.name}. Leave the car where it is.`);
  }
});

/* ==================================================================== *
 * Permitted events
 * ==================================================================== */
$('#event-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const street = $('#event-input').value.trim();
  const host = $('#event-results');
  host.textContent = 'Checking…';
  if (street.length < 3) {
    host.textContent = 'Give it at least three characters.';
    return;
  }
  try {
    const events = await fetchEventsOnStreet(street);
    host.textContent = '';
    if (!events.length) {
      const empty = el('p', 'empty');
      empty.textContent = `No permitted events on ${titleCase(street)} in the next 30 days.`;
      host.append(empty);
      return;
    }
    for (const item of events) {
      const row = el('div', 'event-row');
      const start = new Date(item.start_date_time);
      const end = new Date(item.end_date_time);
      row.innerHTML = `<strong>${esc(item.event_name || item.event_type || 'Permitted event')}</strong>
        <div class="event-when">${start.toLocaleString('en-US', {
          month: 'short',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
        })} – ${end.toLocaleString('en-US', { hour: 'numeric', minute: '2-digit' })}</div>
        <div class="event-when">${esc(item.event_location || '')}</div>`;
      host.append(row);
    }
  } catch (error) {
    host.textContent = '';
    const err = el('p', 'empty');
    err.textContent =
      error instanceof SocrataError ? error.message : `Could not check events: ${error.message}`;
    host.append(err);
  }
});

/* ==================================================================== *
 * Boot
 * ==================================================================== */
(async function start() {
  renderGuide();
  try {
    calendar = await (await fetch('asp-calendar.json')).json();
    renderSuspensions();
  } catch (error) {
    $('#susp-today').innerHTML =
      '<h2>Suspension calendar unavailable</h2><p>The calendar file could not be loaded.</p>';
    console.error(error);
  }
  try {
    renderWatchlist();
    await refreshWatched();
  } catch (error) {
    // A bad stored entry must never take the rest of the page down with it.
    console.error('Watchlist failed:', error);
  }
})();
