#!/usr/bin/env node
//
// Checks npm for newer versions of the libraries in /vendor/, and when it
// finds one: swaps the file, repoints every <script src> in the site, and
// updates vendor.json and the README table.
//
// It never crosses a major version. A new major means the library changed in
// ways that break callers, so those are raised by hand in vendor.json.
//
//   node scripts/update-vendor.mjs          apply updates
//   node scripts/update-vendor.mjs --check  report only, change nothing
//
// Either way it writes vendor/status.json, which the admin panel reads so the
// answer to "is anything waiting?" is visible without opening GitHub.
//
// No dependencies on purpose. The whole point of /vendor/ was to stop running
// other people's code without looking at it; a dependency here would be the
// same mistake one floor up.

import { readFileSync, writeFileSync, existsSync, rmSync, mkdirSync, readdirSync, copyFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Script } from 'node:vm';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const VENDOR = join(ROOT, 'vendor');
const MANIFEST = join(VENDOR, 'vendor.json');
const STATUS = join(VENDOR, 'status.json');
const CHECK_ONLY = process.argv.includes('--check');

const log = (...a) => console.log(...a);

// ── semver, only as much as we need ──────────────────────────────────
// Release versions only: a prerelease has a '-' and is never picked.
function parse(v) {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(v);
  return m ? [ +m[1], +m[2], +m[3] ] : null;
}
function newer(a, b) {           // is a > b
  const x = parse(a), y = parse(b);
  if (!x || !y) return false;
  for (let i = 0; i < 3; i++) { if (x[i] !== y[i]) return x[i] > y[i]; }
  return false;
}

async function latestWithin(pkg, major) {
  const url = 'https://registry.npmjs.org/' + pkg.replace('/', '%2f');
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(pkg + ': npm returned ' + res.status);
  const body = await res.json();
  let best = null;
  for (const v of Object.keys(body.versions || {})) {
    const p = parse(v);
    if (!p || p[0] !== major) continue;                    // wrong major, or a prerelease
    if (body.versions[v].deprecated) continue;
    if (!best || newer(v, best)) best = v;
  }
  if (!best) throw new Error(pkg + ': no release found in major ' + major);
  return best;
}

// ── fetching the file npm actually published ─────────────────────────
function fetchFromNpm(pkg, version, pathInTarball, destFile) {
  const tmp = join(VENDOR, '.tmp-' + Date.now());
  mkdirSync(tmp, { recursive: true });
  try {
    // npm pack writes the tarball into cwd, so give it its own empty one.
    execFileSync('npm', ['pack', pkg + '@' + version, '--silent'], { cwd: tmp, stdio: ['ignore', 'pipe', 'pipe'] });
    const tgz = readdirSync(tmp).find(f => f.endsWith('.tgz'));
    if (!tgz) throw new Error('npm pack produced no tarball for ' + pkg + '@' + version);
    execFileSync('tar', ['-xzf', tgz], { cwd: tmp });
    const src = join(tmp, 'package', pathInTarball);
    if (!existsSync(src)) throw new Error(pkg + '@' + version + ' has no ' + pathInTarball);
    copyFileSync(src, destFile);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// Nothing reaches a pull request without passing this. It will not catch a
// library that changed how it behaves, but it does catch the failures that
// actually happen to a download: truncated, empty, or the wrong file.
function sanityCheck(file, expect) {
  const body = readFileSync(file, 'utf8');
  if (body.length < 1024) throw new Error('file is only ' + body.length + ' bytes — truncated?');
  if (/^\s*<(!doctype|html)/i.test(body)) throw new Error('got an HTML page, not JavaScript');
  try { new Script(body); } catch (e) { throw new Error('does not parse as JavaScript: ' + e.message); }
  if (expect && !body.includes(expect)) throw new Error('does not mention "' + expect + '" — wrong file?');
}

// ── the HTML files that reference /vendor/ ───────────────────────────
function htmlFiles(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'node_modules' || e.name === 'vendor') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) htmlFiles(p, out);
    else if (e.name.endsWith('.html')) out.push(p);
  }
  return out;
}

function repoint(oldName, newName) {
  let touched = 0;
  for (const f of htmlFiles(ROOT)) {
    const s = readFileSync(f, 'utf8');
    if (!s.includes('/vendor/' + oldName)) continue;
    writeFileSync(f, s.split('/vendor/' + oldName).join('/vendor/' + newName));
    touched++;
  }
  return touched;
}

// ── the README's version table, kept in step ─────────────────────────
function rewriteReadmeTable(libs) {
  const readme = join(VENDOR, 'README.md');
  if (!existsSync(readme)) return;
  const s = readFileSync(readme, 'utf8');
  const START = '<!-- versions:start -->', END = '<!-- versions:end -->';
  const i = s.indexOf(START), j = s.indexOf(END);
  if (i < 0 || j < 0) return;                     // markers gone; leave it alone
  const rows = libs.map(l =>
    '| `' + l.localPattern.replace('{version}', l.current) + '` | `' + l.package + '` | ' + l.current + ' |'
  ).join('\n');
  const table = '\n| File | Package | Version |\n|---|---|---|\n' + rows + '\n';
  writeFileSync(readme, s.slice(0, i + START.length) + table + s.slice(j));
}

// ── main ─────────────────────────────────────────────────────────────
const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
const report = [];
let changed = 0, failed = 0;

for (const lib of manifest.libraries) {
  let latest;
  try {
    latest = await latestWithin(lib.package, lib.major);
  } catch (err) {
    failed++;
    log('  ?  ' + lib.name + ': could not check — ' + err.message);
    report.push({ name: lib.name, package: lib.package, current: lib.current, latest: null, behind: false, error: String(err.message) });
    continue;
  }

  const behind = newer(latest, lib.current);
  report.push({ name: lib.name, package: lib.package, current: lib.current, latest, behind, error: null });

  if (!behind) { log('  ok ' + lib.name + ' ' + lib.current); continue; }

  if (CHECK_ONLY) { log('  ^  ' + lib.name + ' ' + lib.current + ' -> ' + latest + ' (available)'); continue; }

  const oldName = lib.localPattern.replace('{version}', lib.current);
  const newName = lib.localPattern.replace('{version}', latest);
  try {
    fetchFromNpm(lib.package, latest, lib.tarballPath, join(VENDOR, newName));
    sanityCheck(join(VENDOR, newName), lib.expect);
    const n = repoint(oldName, newName);
    if (n === 0) throw new Error('no page referenced ' + oldName + ' — refusing to leave an orphan file');
    if (oldName !== newName && existsSync(join(VENDOR, oldName))) rmSync(join(VENDOR, oldName));
    lib.current = latest;
    changed++;
    log('  ^  ' + lib.name + ' ' + oldName + ' -> ' + newName + ' (' + n + ' page' + (n === 1 ? '' : 's') + ')');
  } catch (err) {
    failed++;
    // Leave the site pointing at the version that works.
    if (existsSync(join(VENDOR, newName))) rmSync(join(VENDOR, newName));
    log('  !  ' + lib.name + ': update failed, left at ' + lib.current + ' — ' + err.message);
    report[report.length - 1].error = String(err.message);
  }
}

if (changed) {
  writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + '\n');
  rewriteReadmeTable(manifest.libraries);
}

// status.json is what the admin panel reads. Written on every run, so the
// "last checked" date is honest even when there was nothing to do.
writeFileSync(STATUS, JSON.stringify({
  checkedAt: new Date().toISOString(),
  behind: report.filter(r => r.behind).length,
  errors: report.filter(r => r.error).length,
  libraries: report
}, null, 2) + '\n');

log('\n' + (CHECK_ONLY ? 'check only. ' : '') +
    report.filter(r => r.behind).length + ' behind, ' + changed + ' updated, ' + failed + ' failed.');

// A failed check is worth a red build; nothing to do is not.
process.exit(failed ? 1 : 0);
