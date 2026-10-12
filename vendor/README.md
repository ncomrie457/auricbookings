# vendor/ — the JavaScript libraries this site depends on

These used to load from `cdn.jsdelivr.net` at page load. They are now served
from this site, which means:

- **Nothing can change them but you.** A CDN serving a tampered file would
  have run with full access to pages that take payments and collect health
  disclosures. That route is closed.
- **No visitor IP goes to a CDN.** Loading a script from a third party tells
  that third party who is reading your site and when.
- **The site cannot break because someone else had an outage.**

Nothing here updates itself. A monthly GitHub Action
(`.github/workflows/vendor-update.yml`) checks npm, and when something newer
exists it opens a **pull request** with the swap already made — the site does
not change until that PR is merged. The admin panel shows the result of the
last check, so "is anything waiting?" is answerable without opening GitHub.

## What is here, and where it came from

The table below is rewritten by `scripts/update-vendor.mjs`. Edit
`vendor.json`, not this table.

<!-- versions:start -->
| File | Package | Version |
|---|---|---|
| `supabase-js-2.117.3.min.js` | `@supabase/supabase-js` | 2.117.3 |
| `emailjs-browser-4.4.1.min.js` | `@emailjs/browser` | 4.4.1 |
| `jspdf-2.5.2.umd.min.js` | `jspdf` | 2.5.2 |
| `gsap-3.15.0.min.js` | `gsap` | 3.15.0 |
| `gsap-scrolltrigger-3.15.0.min.js` | `gsap` | 3.15.0 |
| `lenis-1.3.26.min.js` | `lenis` | 1.3.26 |
<!-- versions:end -->

Every file was taken from the official npm tarball, unmodified. They are the
same builds jsDelivr was serving: for Supabase that is `dist/umd/supabase.js`,
the file the package itself nominates for CDNs, and for the rest it is the
`dist/` build the old URLs named.

Two of the old URLs floated — `@supabase/supabase-js@2` and
`@emailjs/browser@4` meant "whatever the newest 2.x and 4.x are today". The
site was running whatever those projects published next, unreviewed, on every
page load. These are now pinned to the versions in the table.

## Updating one

Pick the file you want to update, then from any machine with `npm`:

```sh
# e.g. Supabase. Replace the version with the one you want.
npm pack @supabase/supabase-js@2.118.0
tar -xzf supabase-supabase-js-2.118.0.tgz
cp package/dist/umd/supabase.js vendor/supabase-js-2.118.0.min.js
```

Then point the `<script src="/vendor/...">` tags at the new filename and
delete the old file. Keeping the version in the filename is deliberate: a
browser that cached the old one cannot serve it in place of the new one.

The tags live in these pages — all of them, or the page breaks:

```
index.html                   supabase, emailjs, jspdf, gsap, scrolltrigger, lenis
waiver/index.html            supabase, emailjs, jspdf
sign/cr-ga-9m4kx7/index.html supabase, emailjs
blooming/index.html          supabase, emailjs
northwell/index.html         supabase, emailjs
blooming-list/index.html     supabase
expenses/index.html          supabase
recharge-list/index.html     supabase
reserve-bag/index.html       supabase
riddim-interest/index.html   supabase
```

Paths are root-absolute (`/vendor/...`), so they are the same string on every
page regardless of how deep the page sits.
