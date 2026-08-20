import { test } from 'node:test';
import assert from 'node:assert/strict';
import { latLonToStatePlane, statePlaneToLatLon } from '../nycdata.js';

test('the projection origin maps to the false easting exactly', () => {
  // At the central meridian and the latitude of false origin, EPSG:2263 is
  // defined to return (false easting, false northing) = (984250 ft, 0).
  const p = latLonToStatePlane(40.16666666666667, -74.0);
  assert.ok(Math.abs(p.x - 984250) < 0.01, `x was ${p.x}`);
  assert.ok(Math.abs(p.y - 0) < 0.01, `y was ${p.y}`);
});

test('Empire State Building lands where midtown Manhattan should', () => {
  // 40.748817, -73.985428. Derived independently: the point sits 0.58215 deg
  // north of the origin (~212,100 ft of meridian arc) and 0.014572 deg east of
  // the central meridian (~4,040 ft at this latitude).
  const p = latLonToStatePlane(40.748817, -73.985428);
  assert.ok(Math.abs(p.x - 988290) < 500, `x was ${p.x}`);
  assert.ok(Math.abs(p.y - 212100) < 900, `y was ${p.y}`);
});

test('forward and inverse round-trip to sub-inch accuracy', () => {
  for (const [lat, lon] of [
    [40.748817, -73.985428], // Manhattan
    [40.6782, -73.9442], // Brooklyn
    [40.7282, -73.7949], // Queens
    [40.8448, -73.8648], // Bronx
    [40.5795, -74.1502], // Staten Island
  ]) {
    const p = latLonToStatePlane(lat, lon);
    const back = statePlaneToLatLon(p.x, p.y);
    assert.ok(Math.abs(back.lat - lat) < 1e-8, `lat ${back.lat} vs ${lat}`);
    assert.ok(Math.abs(back.lon - lon) < 1e-8, `lon ${back.lon} vs ${lon}`);
  }
});

test('all five boroughs fall inside the documented coordinate range', () => {
  for (const [lat, lon] of [
    [40.748817, -73.985428],
    [40.6782, -73.9442],
    [40.7282, -73.7949],
    [40.8448, -73.8648],
    [40.5795, -74.1502],
  ]) {
    const { x, y } = latLonToStatePlane(lat, lon);
    assert.ok(x > 900000 && x < 1090000, `x out of NYC range: ${x}`);
    assert.ok(y > 110000 && y < 275000, `y out of NYC range: ${y}`);
  }
});
