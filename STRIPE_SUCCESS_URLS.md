# Stripe success URLs — Oct 10 & Nov 21 Brooklyn

In Stripe, open each payment link → **After payment** → **Redirect customers to your
website** → paste the matching URL below.

The `s=` value is what tells the page which session to confirm. It has to match
exactly, or the buyer sees the wrong time.

---

## Saturday, October 10 — Maison Luxe

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 12:00 PM | `…9sk0i` | `https://book.auricmovement.com/?paid=reformer-o10&s=o12` |
| 1:00 PM | `…9sk0k` | `https://book.auricmovement.com/?paid=reformer-o10&s=o1` |
| 2:00 PM | `…9sk0l` | `https://book.auricmovement.com/?paid=reformer-o10&s=o2` |
| 3:00 PM | `…9sk0m` | `https://book.auricmovement.com/?paid=reformer-o10&s=o3` |

## Saturday, November 21 — Maison Luxe

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 12:00 PM | `…9sk0j` | `https://book.auricmovement.com/?paid=reformer-n21&s=n12` |
| 1:00 PM | `…9sk0n` | `https://book.auricmovement.com/?paid=reformer-n21&s=n1` |
| 2:00 PM | `…9sk0o` | `https://book.auricmovement.com/?paid=reformer-n21&s=n2` |
| 3:00 PM | `…9sk0p` | `https://book.auricmovement.com/?paid=reformer-n21&s=n3` |

---

## What the buyer sees once this is set

"✔ Payment received — you're booked!", the right session name, and the
add-to-calendar buttons (Google, Apple, Outlook, Office 365, .ics).

Without it they stop on Stripe's own receipt page. The confirmation email still
sends either way — this is about where they land, not whether they're booked.

All eight were checked in a browser: each URL confirms its own session and shows
five calendar buttons.

## For reference — the two existing dates

| Event | Redirect pattern |
|---|---|
| Sept 26 Brooklyn | `?paid=reformer-bk&s=bk12` / `bk1` / `bk2` |
| Sept 13 West Hempstead | `?paid=reformer&s=1pm` / `2pm` / `3pm` |
