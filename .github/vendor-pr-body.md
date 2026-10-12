The monthly check found newer versions of one or more libraries in `/vendor/`.

**Nothing on the live site has changed.** These files are served from the site
itself, so the versions visitors load are whatever is on `main`. Merging this
is what puts them live.

Each file here was downloaded from the official npm package, inside the major
version pinned in `vendor/vendor.json`, and had to pass three checks before it
was accepted: a sensible size, it parses as JavaScript, and it mentions the
symbol the site actually calls.

What that does **not** prove is that the library still behaves the same way.
Staying inside a major version makes a break unlikely, but if you want to be
sure before merging, open a booking page and the admin panel from this branch
and check they load.

See `vendor/README.md` for what each library does and why they live here.
