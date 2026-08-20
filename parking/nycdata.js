/**
 * nycdata.js — talks to the live NYC Open Data (Socrata) endpoints.
 *
 * Nothing is bundled or cached server-side: every lookup hits DOT's current
 * table, so when DOT posts a new sign order the app shows it on the next
 * search. That is the whole point of querying rather than shipping a copy.
 *
 * Datasets
 *   nfid-uabd  Parking Regulation Locations and Signs (DOT, ~1M signs)
 *   tvpp-9vvx  NYC Permitted Event Information (street events, next ~30 days)
 */

const HOST = 'https://data.cityofnewyork.us/resource';
export const SIGNS_DATASET = 'nfid-uabd';
export const EVENTS_DATASET = 'tvpp-9vvx';

export const DATASET_LINKS = {
  signs: 'https://data.cityofnewyork.us/Transportation/Parking-Regulation-Locations-and-Signs/nfid-uabd',
  events: 'https://data.cityofnewyork.us/City-Government/NYC-Permitted-Event-Information/tvpp-9vvx',
};

/** Socrata allows anonymous use; an app token just buys a higher rate limit. */
function appToken() {
  try {
    return localStorage.getItem('nycparking.appToken') || '';
  } catch {
    return '';
  }
}

export class SocrataError extends Error {
  constructor(message, { status, dataset, query } = {}) {
    super(message);
    this.name = 'SocrataError';
    this.status = status;
    this.dataset = dataset;
    this.query = query;
  }
}

async function soql(dataset, params, { signal } = {}) {
  const url = new URL(`${HOST}/${dataset}.json`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, v);
  }
  const headers = {};
  const token = appToken();
  if (token) headers['X-App-Token'] = token;

  let res;
  try {
    res = await fetch(url, { headers, signal });
  } catch (cause) {
    throw new SocrataError(
      'Could not reach NYC Open Data. Check your connection and try again.',
      { dataset, query: url.search }
    );
  }
  if (!res.ok) {
    let detail = '';
    try {
      const body = await res.json();
      detail = body.message || body.errorCode || '';
    } catch {
      /* non-JSON error body */
    }
    if (res.status === 429) {
      throw new SocrataError(
        'NYC Open Data is rate-limiting anonymous requests right now. Wait a moment, or add a free app token in Settings.',
        { status: 429, dataset, query: url.search }
      );
    }
    throw new SocrataError(detail || `NYC Open Data returned ${res.status}.`, {
      status: res.status,
      dataset,
      query: url.search,
    });
  }
  return res.json();
}

/** Escape a value for a single-quoted SoQL string literal. */
function q(value) {
  return String(value).replace(/'/g, "''");
}

/* ------------------------------------------------------------------ *
 * NAD83 / New York Long Island (ftUS) — EPSG:2263
 * DOT stores sign_x_coord / sign_y_coord in this system, not lat/lon,
 * so "near me" has to project the browser's GPS fix into it.
 * Lambert Conformal Conic, two standard parallels.
 * ------------------------------------------------------------------ */
const GRS80_A = 6378137.0;
const GRS80_F = 1 / 298.257222101;
const E = Math.sqrt(2 * GRS80_F - GRS80_F * GRS80_F);
const M_TO_FTUS = 3937 / 1200;
const RAD = Math.PI / 180;

const PHI0 = 40.16666666666667 * RAD; // latitude of false origin
const PHI1 = 40.66666666666666 * RAD; // standard parallel 1
const PHI2 = 41.03333333333333 * RAD; // standard parallel 2
const LON0 = -74.0 * RAD; // central meridian
const FALSE_EASTING_FT = 984250.0;
const FALSE_NORTHING_FT = 0.0;

const mOf = (phi) => Math.cos(phi) / Math.sqrt(1 - E * E * Math.sin(phi) ** 2);
const tOf = (phi) =>
  Math.tan(Math.PI / 4 - phi / 2) /
  ((1 - E * Math.sin(phi)) / (1 + E * Math.sin(phi))) ** (E / 2);

const M1 = mOf(PHI1);
const M2 = mOf(PHI2);
const T0 = tOf(PHI0);
const T1 = tOf(PHI1);
const T2 = tOf(PHI2);
const N = (Math.log(M1) - Math.log(M2)) / (Math.log(T1) - Math.log(T2));
const BIG_F = M1 / (N * T1 ** N);
const R0 = GRS80_A * BIG_F * T0 ** N;

/** WGS84 lat/lon -> NY State Plane Long Island feet. */
export function latLonToStatePlane(lat, lon) {
  const phi = lat * RAD;
  const r = GRS80_A * BIG_F * tOf(phi) ** N;
  const theta = N * (lon * RAD - LON0);
  return {
    x: FALSE_EASTING_FT + r * Math.sin(theta) * M_TO_FTUS,
    y: FALSE_NORTHING_FT + (R0 - r * Math.cos(theta)) * M_TO_FTUS,
  };
}

/** NY State Plane Long Island feet -> WGS84 lat/lon. */
export function statePlaneToLatLon(x, y) {
  const east = (x - FALSE_EASTING_FT) / M_TO_FTUS;
  const north = (y - FALSE_NORTHING_FT) / M_TO_FTUS;
  const rPrime = Math.sign(N) * Math.hypot(east, R0 - north);
  const tPrime = (rPrime / (GRS80_A * BIG_F)) ** (1 / N);
  const theta = Math.atan2(east, R0 - north);
  const lon = theta / N + LON0;

  let phi = Math.PI / 2 - 2 * Math.atan(tPrime);
  for (let i = 0; i < 12; i++) {
    const next =
      Math.PI / 2 -
      2 *
        Math.atan(
          tPrime * ((1 - E * Math.sin(phi)) / (1 + E * Math.sin(phi))) ** (E / 2)
        );
    if (Math.abs(next - phi) < 1e-12) {
      phi = next;
      break;
    }
    phi = next;
  }
  return { lat: phi / RAD, lon: lon / RAD };
}

/* ------------------------------------------------------------------ *
 * Sign queries
 * ------------------------------------------------------------------ */

/** A sign order is live unless DOT has voided the design or flagged it historical. */
function isCurrent(row) {
  if (row.sign_design_voided_on_date) return false;
  const type = String(row.record_type || '').toUpperCase();
  if (type && /HIST|VOID|REMOV/.test(type)) return false;
  return true;
}

const SIGN_FIELDS = [
  'order_number',
  'record_type',
  'borough',
  'on_street',
  'from_street',
  'to_street',
  'side_of_street',
  'sign_code',
  'sign_description',
  'sign_location',
  'distance_from_intersection',
  'arrow_direction',
  'facing_direction',
  'sign_design_voided_on_date',
  'order_completed_on_date',
  'sign_x_coord',
  'sign_y_coord',
].join(',');

/**
 * Every sign on the blocks of a named street. The caller picks a block from
 * the grouped result — we deliberately do not filter by borough server-side,
 * because DOT's borough encoding varies between exports.
 */
export async function fetchSignsOnStreet(street, { limit = 4000, signal } = {}) {
  const needle = q(street.trim().toUpperCase());
  const rows = await soql(
    SIGNS_DATASET,
    {
      $select: SIGN_FIELDS,
      $where: `upper(on_street) like '%${needle}%'`,
      $limit: limit,
    },
    { signal }
  );
  return rows.filter(isCurrent);
}

/**
 * Signs within `radiusFt` of a lat/lon.
 *
 * The server-side filter is a bounding box on the State Plane columns. Those
 * columns come back as strings in some Socrata exports, which would make the
 * comparison lexicographic rather than numeric — so every row is re-checked
 * client-side against the true distance. Worst case that makes the result
 * incomplete; it never makes it wrong.
 */
export async function fetchSignsNear(lat, lon, { radiusFt = 600, limit = 2000, signal } = {}) {
  const { x, y } = latLonToStatePlane(lat, lon);
  const pad = radiusFt;
  const rows = await soql(
    SIGNS_DATASET,
    {
      $select: SIGN_FIELDS,
      $where: [
        `sign_x_coord > ${Math.round(x - pad)}`,
        `sign_x_coord < ${Math.round(x + pad)}`,
        `sign_y_coord > ${Math.round(y - pad)}`,
        `sign_y_coord < ${Math.round(y + pad)}`,
      ].join(' AND '),
      $limit: limit,
    },
    { signal }
  );

  return rows
    .filter(isCurrent)
    .map((row) => {
      const sx = Number(row.sign_x_coord);
      const sy = Number(row.sign_y_coord);
      if (!Number.isFinite(sx) || !Number.isFinite(sy)) return null;
      return { ...row, distanceFt: Math.hypot(sx - x, sy - y) };
    })
    .filter((row) => row && row.distanceFt <= radiusFt)
    .sort((a, b) => a.distanceFt - b.distanceFt);
}

/** Group flat sign rows into block faces: one street, between two cross streets, one side. */
export function groupIntoBlocks(rows) {
  const blocks = new Map();
  for (const row of rows) {
    const key = [
      row.borough,
      row.on_street,
      row.from_street,
      row.to_street,
      row.side_of_street,
    ]
      .map((v) => String(v || '').trim().toUpperCase())
      .join('|');
    if (!blocks.has(key)) {
      blocks.set(key, {
        key,
        borough: row.borough,
        onStreet: row.on_street,
        fromStreet: row.from_street,
        toStreet: row.to_street,
        side: row.side_of_street,
        signs: [],
        nearestFt: Infinity,
      });
    }
    const block = blocks.get(key);
    block.signs.push(row);
    if (Number.isFinite(row.distanceFt)) {
      block.nearestFt = Math.min(block.nearestFt, row.distanceFt);
    }
  }
  for (const block of blocks.values()) {
    block.signs.sort(
      (a, b) =>
        (Number(a.distance_from_intersection) || 0) -
        (Number(b.distance_from_intersection) || 0)
    );
  }
  return [...blocks.values()];
}

/* ------------------------------------------------------------------ *
 * Permitted events — block parties, filming, races. These suspend or
 * override the posted regulation for the day.
 * ------------------------------------------------------------------ */
export async function fetchEventsOnStreet(street, { days = 30, signal } = {}) {
  const needle = q(street.trim().toUpperCase());
  const now = new Date();
  const until = new Date(now.getTime() + days * 86400000);
  const rows = await soql(
    EVENTS_DATASET,
    {
      $select:
        'event_id,event_name,event_type,event_borough,event_location,event_street_side,start_date_time,end_date_time,event_agency',
      $where: [
        `upper(event_location) like '%${needle}%'`,
        `end_date_time > '${now.toISOString().slice(0, 19)}'`,
        `start_date_time < '${until.toISOString().slice(0, 19)}'`,
      ].join(' AND '),
      $order: 'start_date_time',
      $limit: 200,
    },
    { signal }
  );
  return rows;
}
