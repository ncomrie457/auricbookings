# Admin login setup — Step 3 (create your login)

We're replacing the shared admin password with a real login. This is the
one thing you do before I flip it live, so you don't get locked out.

## Create your admin account (2 minutes)

1. Go to your **Supabase dashboard** → your project.
2. Left sidebar → **Authentication**.
3. Click the **Users** tab → **Add user** → **Create new user**.
4. Fill in:
   - **Email:** your email (e.g. niara.comrie@gmail.com)
   - **Password:** pick a strong password — **this is your new admin password.**
     Write it down somewhere safe. I never see it and it is never in the code.
   - ✅ **Check "Auto Confirm User"** (so you can log in immediately without a
     confirmation email).
5. Click **Create user**.

That's it. Tell me when it's done and I'll flip the new login live. You'll then
open the admin panel the same way as always (the `#admin` link / shortcut), but
instead of typing one shared word you'll enter **your email + your password**.

## What changes for you
- **Opening admin:** email + password login (instead of the shared word).
- **Staying signed in:** your browser remembers you, so you won't retype it
  every time. There's a new **🔒 Log out** button in the admin toolbar.
- **Nothing changes for your customers** — booking and signup forms are untouched.

## What's still coming (Step 4 — the lockdown, after login works)
Once you can log in, I run a database migration that:
- Locks reading/editing/deleting your registrant data to **you, logged in**
  (right now the public key can read most of it — this closes that).
- Rewrites the reformer functions to require your login instead of the password.
- Removes the last copy of the old password from the site's code.
- Adds your **collaborator** login (Something's Blooming list, view + export only).

We do Step 4 right after Step 3 works, so there's never a moment where the
site is broken.
