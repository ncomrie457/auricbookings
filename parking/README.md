# NYC Parking Signs

A single-page app that answers "what is actually posted on this block?" using
New York City's own sign database — three-hour metered, commercial vehicles
only, alternate side, and the rest — plus the holiday suspension calendar.

Live at `/parking/` on this site. No build step, no server, no dependencies.

## Why it exists when the city has one

NYC DOT already publishes a sign locator at
[nycdotsigns.net](https://nycdotsigns.net/), and SpotAngels already does
alternate-side reminders. Neither one puts the posted regulation, the
suspension calendar, and street-event closures for the same block in one
place, and neither will tell you when a sign on *your* block changed. That
last part is what this adds.

## How it works

| Piece | Source |
| --- | --- |
| Sign text and locations | [DOT — Parking Regulation Locations and Signs](https://data.cityofnewyork.us/Transportation/Parking-Regulation-Locations-and-Signs/nfid-uabd) (`nfid-uabd`) |
| Street events and closures | [NYC Permitted Event Information](https://data.cityofnewyork.us/City-Government/NYC-Permitted-Event-Information/tvpp-9vvx) (`tvpp-9vvx`) |
| Holiday suspensions | `asp-calendar.json` in this folder |

Every lookup queries Socrata live from the browser. Nothing is bundled or
mirrored, so **a newly posted sign order appears as soon as DOT publishes it**
— there is no copy of the data here to go stale.

### Files

- `signs.js` — turns DOT's raw sign text into a category, days, hours and a
  plain-English sentence. Pure functions, no DOM.
- `nycdata.js` — Socrata queries, plus the EPSG:2263 projection needed to turn
  a GPS fix into the State Plane feet that DOT stores coordinates in.
- `suspensions.js` — the suspension calendar and the `.ics` export.
- `guide.js` — reference copy for the Sign guide tab.
- `app.js` — UI wiring.

### Watching a block

Starring a block stores a fingerprint of its current signs in `localStorage`.
On every later visit the app re-queries DOT, diffs the two, and flags anything
added or removed. That is a client-side diff: it works without a server, but
only notices a change the next time you open the page.

### Notifications

A static page cannot push you anything while it is closed — that needs a
server. Two things do work:

1. **The `.ics` download** puts every suspension day into your phone's
   calendar with an alarm the evening before. This is the reliable one.
2. **Web notifications** fire while the page is open, for watched-block
   changes and next-day suspensions.

Real push (weather suspensions announced that morning, a sign posted
overnight) would need a small backend polling DOT and holding subscriptions.

## The calendar needs verifying

`asp-calendar.json` is currently `"verified": false`. The dates were compiled
from press reporting of DOT's 2026 calendar, not read off the source, so the
app labels them as unconfirmed everywhere they appear.

To fix that, open
[DOT's official 2026 PDF](https://www.nyc.gov/html/dot/downloads/pdf/asp-calendar-2026.pdf),
check the list line by line, correct anything wrong, resolve the entries under
`knownGaps`, and set `"verified": true`. The unconfirmed banner disappears on
its own.

A new file is needed each year; DOT publishes the next calendar in the autumn.

## Tests

```
cd parking && node --test "tests/*.test.mjs"
```

Covers the sign-text parser (day and time windows, overnight wraps, duration
limits, category precedence), the State Plane projection (against the
projection's defined origin and an independently derived Manhattan reference
point), and the iCalendar output (fold width, escaping, all-day roll-over).

The Socrata calls themselves are exercised by an end-to-end Playwright run
against stubbed responses — the network path is not covered by unit tests.

## Limits worth knowing

- DOT's database lags the street. A crew that installed a sign this morning
  may not show up for days. **The pole wins.**
- Not every sign row carries coordinates, so "Near me" can miss signs that the
  street lookup finds.
- Weather and emergency suspensions are announced same-day and are in no
  dataset here. 311 has those.
- Anonymous Socrata use is rate-limited. If you hit it, register a free app
  token and set it: `localStorage.setItem('nycparking.appToken', 'YOUR_TOKEN')`.
