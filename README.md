# WorkLog

A Flutter freelancer app — work tracking, clients & invoicing, finance,
and an optional Gym & Diet module — backed by Supabase (Postgres +
Auth + Storage), for a USA + Pakistan freelancer/creator audience
(video editors, AI UGC, motion graphics). Multi-user accounts with
real email/password + Google authentication, Riverpod + repository
pattern, multi-currency, realtime, responsive (phone bottom nav /
tablet side rail).

## What's included

**Auth** — Email/password sign-up with email verification (resend +
cooldown), Google Sign-In, forgot/reset password, all the specified
error states (generic "incorrect email or password", unverified-email
resend prompt, rate-limit message, etc.) — see
`lib/features/auth/`.

**Onboarding** — 4-screen flow shown once right after first sign-in:
Welcome → "track fitness too?" choice → notification permission →
Done. Sets `gym_enabled` on the profile row, which is what actually
drives the nav below. See `lib/features/onboarding/`.

**Profile tab** (replaces the old Settings screen) — avatar (upload
via Storage) + name, default currency, invoice name, theme
(Light/Dark/Auto), the Gym & Diet toggle (with a confirm dialog on
turning it off — data is hidden, never deleted), change password,
logout, delete account, and the About section (version, privacy
policy, terms, feedback). See `lib/features/profile/`.

**Bottom navigation** — 5 slots, "+" Quick Entry fixed in the center
slot *inside* the bar (not a separate floating button), Profile
always last:
- Gym **ON**: Home · Gym · **+** · Finance · Profile — Clients has no
  tab; it's reached from the **+** sheet instead (full add/manage).
- Gym **OFF**: Home · Finance · **+** · Clients · Profile — Clients is
  a normal tab.

See `lib/app/app_shell.dart`.

**Home** — time-of-day greeting with the user's name, hero earnings
card, today's videos/tasks/hours/income stat grid, upcoming reminders,
a first-run "Add your first client" prompt, pull-to-refresh.

**Clients** — CRUD, Call/Email/WhatsApp quick-action buttons on Client
Detail (native intents), sort by name/total earned/pending amount,
free-text notes, rollup totals maintained by Postgres triggers (never
written by the app directly) so they can't drift.

**Work** — Work entry CRUD, filters, Video Stats screen.

**Finance** — Income/expense entry, multi-currency (never
auto-converted — each transaction keeps its own ISO currency code),
Pending Payments ("Money I Need to Receive") with an invoice-download
icon per project, Analytics, monthly PDF Financial Reports.

**Invoices** — Per-project PDF (now includes an invoice number and an
optional Payment Instructions block from the Profile). Download →
native OS share sheet, which is how Email (subject/body pre-filled but
fully editable) and WhatsApp sharing both work — one flow, per spec
Section 4, rather than separate custom integrations.

**Gym & Diet** (optional module, see the Profile toggle) — Workouts,
routines, exercise library, diet/meal logging, body stats & goals.

**Time tracking** — a Start/Stop timer on each Work Entry (shown once
the entry is saved/edited), adding elapsed time to Hours Worked rather
than overwriting it; a small clock icon marks entries with a timer
currently running, wherever they show up in lists.

**Recurring (retainer) invoices** — mark a client as a retainer on the
Client form (monthly amount, currency, billing day). A new invoice is
created automatically once a month, checked on Home launch (and
available any time via "Generate Now" on Client Detail); the DB
function behind it (`generate_due_retainer_invoices`) is also ready
for an optional pg_cron schedule so it still fires on days nobody
opens the app — see the commented block at the end of `schema.sql`.

**Late-payment reminders** — on Home launch, newly-overdue invoices
(past due date, not fully paid, not already alerted) get an immediate
local notification; each is marked so it only fires once. Same
pg_cron-ready pattern as retainer invoices if you want a true
server-side check later.

**CSV export/import** — Profile → Data → "Export Data (CSV)" shares
four files in one go (clients, work entries, income, expenses) via the
native share sheet; "Import Income (CSV)" reads a file back in using
the same column layout, matching each row's client by exact name.

**Reminders** — CRUD, priority, repeat, local notification scheduling.

**Search** — Global search across clients, work entries, reminders.

**AI assistant (optional)** — Home and the Gym, Work, Finance, and
Reminders screens provide an assistant entry point. It sends fixed task
selections plus allow-listed aggregate metrics through the authenticated
`worklog-assistant` Edge Function. No free-text prompt, client details,
notes, or transaction rows are sent. The first use requires explicit
consent; the feature can be disabled from Profile. The function only
returns recommendations/drafts; users review them in the app before
making any changes. To enable it, configure `GEMINI_API_KEY` as a
Supabase Edge Function secret and deploy `worklog-assistant`. Keep the
key out of Flutter defines, browser assets, and source control. Gemini's
free-tier privacy terms may permit submitted content to improve Google
products; review Google's current terms and limits before enabling it.

## Architecture notes

- **Rollups live in Postgres, not Dart.** Client/project totals are
  maintained by triggers in `supabase/schema.sql` — the app's
  repositories never write those columns directly.
- **Realtime.** Every repository's `watch*` method streams from
  Supabase, including the profile row itself — so toggling Gym on one
  device updates the nav on every other signed-in session live.
- **Auth-state-driven routing.** `lib/app/router.dart`'s `redirect`
  handles, in priority order: mid password-recovery → signed-out →
  signed-in-but-not-onboarded → normal navigation. A `ChangeNotifier`
  bridges the async auth/profile streams into GoRouter's
  `refreshListenable`.
- **RLS.** Every table needs Row Level Security scoping rows to
  `auth.uid()` — the base `schema.sql` sets this up; double-check
  after any schema change with the query at the bottom of the v2
  migration section.

## Getting it running

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL Editor** → paste the entire contents of `supabase/schema.sql`
   (base schema **and** the "V2 — PROFILE SETTINGS..." section
   appended at the bottom — it's all one file, safe to run as one
   paste) → **Run**.
3. **Authentication → Providers** → enable **Google** if you want
   Google Sign-In; you'll need an OAuth **Web** client ID from Google
   Cloud Console. For Android, also add your app's SHA-1 fingerprint
   there.
4. **Authentication → URL Configuration → Redirect URLs** → add both:
   - `io.worklog.app://login-callback/`
   - `io.worklog.app://reset-callback/`
5. **Authentication → SMTP Settings** → connect a real provider
   (Resend or Brevo recommended) before any public launch — Supabase's
   built-in sender is capped at 2 emails/hour, nowhere near enough for
   verification + reset emails.
6. **Project Settings → API** → copy the Project URL and **anon** key.
7. Run with your keys (never commit real ones):
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key \
     --dart-define=GOOGLE_WEB_CLIENT_ID=your-id.apps.googleusercontent.com
   ```
8. `flutter pub get` then `flutter run`.

The app is targeted and validated for Android and web. The iOS project
files are retained in the repository but are not a supported release
target.

Without the dart-defines set, the app shows a "Connect Supabase" screen
instead of crashing.

## Known simplifications / not-yet-built

- Section 2.7's CAPTCHA ("Attack Protection") and MFA are Supabase
  **Dashboard** toggles, not app code — MFA is explicitly deferred per
  spec anyway.
- Direct public invoice link (Section 4.4): the database side already
  exists in `schema.sql` (`share_token` column + `get_public_invoice`
  function, safe for the anon key to call). What's still missing is
  the actual public page and Netlify deployment, plus the in-app
  button that reveals the link once that page exists.
- Recurring invoices, automated late-payment reminders, CSV
  export/import, and built-in time tracking (roadmap items 5–9) are
  all built now — see "What's included" above for how each works and
  its specific limits (e.g. retainer generation and the overdue check
  both run client-side on Home launch; wire up the commented pg_cron
  jobs in `schema.sql` if you want them to also run server-side on
  days nobody opens the app).
- A few "detail pass" polish items from the UI spec are partial: swipe
  actions on Work Entries, shimmer skeleton loaders (today it's a
  lightweight `···` placeholder instead), recurring-expense flag,
  client sort is name/earned/pending only (no explicit filter chips
  yet).
- **This code has not been compiled or run** — no Flutter SDK is
  available in the environment it was written in, so nothing has been
  through `flutter analyze` or a real build. It's been checked by hand
  (bracket-balance scans, cross-checking every provider/repository
  call against its definition, tracing every import path). Expect to
  fix a small issue or two on first `flutter pub get` / `flutter run`;
  paste any error back and it'll get fixed.

## Folder structure

```
lib/
  app/              router, theme, responsive shell (bottom nav / side rail)
  core/             config, error handling, shared widgets, utils, pdf
  features/
    auth/           sign-up, login, forgot/reset password, Google
    onboarding/      4-screen first-run flow
    profile/         Profile tab, edit profile, change password
    home/
    work/
    clients/
    finance/
    gym/             optional module (toggle in Profile)
    reminders/
    search/
  services/notifications/
supabase/
  schema.sql        base schema + appended V2 migration — run once
```
