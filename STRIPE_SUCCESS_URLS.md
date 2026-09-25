# Stripe success URLs

In Stripe, open each payment link → **After payment** → **Redirect customers to
your website** → paste the matching URL.

The `s=` value tells the page which session to confirm. It has to match
exactly, or the buyer is shown the wrong time. Stripe adds its own
`?session_id=…` on the end — that is fine, the page ignores it.

Without a redirect the buyer stops on Stripe's own receipt page. **The
confirmation email still sends either way** — this is only about where they
land, and whether they get the add-to-calendar buttons.

---

## Sunday, November 22 — Pre-Turkey Burn · Valley Studio

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 11:30 AM | `…9sk0t` | `https://book.auricmovement.com/?paid=turkey&s=tb1130` |
| 12:30 PM | `…9sk0d` | `https://book.auricmovement.com/?paid=turkey&s=tb1230` |
| 1:30 PM | `…9sk0c` | `https://book.auricmovement.com/?paid=turkey&s=tb130` |

## Saturday, November 28 — Post-Turkey Burn · Valley Studio

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 11:30 AM | `…9sk0q` | `https://book.auricmovement.com/?paid=turkey28&s=tb28_1130` |
| 12:30 PM | `…9sk0h` | `https://book.auricmovement.com/?paid=turkey28&s=tb28_1230` |
| 1:30 PM | `…9sk0r` | `https://book.auricmovement.com/?paid=turkey28&s=tb28_130` |

## Saturday, October 24 — Shhh… Quiet on the Creek · Valley Studio

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 11:30 AM | `…9sk0s` | `https://book.auricmovement.com/?paid=halloween&s=hw1130` |
| 12:30 PM | `…9sk0e` | `https://book.auricmovement.com/?paid=halloween&s=hw1230` |
| 1:30 PM | `…9sk0f` | `https://book.auricmovement.com/?paid=halloween&s=hw130` |

## Saturday, October 10 — Riddim & Kompa · Maison Luxe

| Session | Stripe link ends in | Redirect to |
|---|---|---|
| 12:00 PM | `…9sk0i` | `https://book.auricmovement.com/?paid=reformer-o10&s=o12` |
| 1:00 PM | `…9sk0k` | `https://book.auricmovement.com/?paid=reformer-o10&s=o1` |
| 2:00 PM | `…9sk0l` | `https://book.auricmovement.com/?paid=reformer-o10&s=o2` |
| 3:00 PM | `…9sk0m` | `https://book.auricmovement.com/?paid=reformer-o10&s=o3` |

## Saturday, November 21 — Riddim & Kompa · Maison Luxe

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

Every URL above was loaded in a browser: each one confirms its own session and
shows five calendar buttons.

## Older dates, for reference

| Event | Redirect pattern |
|---|---|
| Sept 26 Brooklyn | `?paid=reformer-bk&s=bk12` / `bk1` / `bk2` |
| Sept 13 West Hempstead | `?paid=reformer&s=1pm` / `2pm` / `3pm` |

`/turkey-paid-1230` and `/turkey-paid-130` are older wrapper pages that just
forward to the `?paid=turkey&s=…` URLs above. They still work, but the direct
URLs in this table do the same thing with nothing extra to maintain.
