# WorkLog

**Your freelance work, clearly tracked.**

WorkLog is an Android app that helps freelancers keep clients, projects, work logs, time, invoices and finances in one place. It is built for independent workers such as video editors, AI UGC creators, motion designers, developers, writers and marketers, with multi-currency support for freelancers working with clients in the USA, Pakistan and beyond.

- **Website:** https://worklog-site.netlify.app
- **Download the app:** https://worklog-site.netlify.app/download/
- **Latest APK (direct):** https://github.com/biilalahmad/worklog/releases/latest/download/WorkLog.apk
- **Support:** worklog.support@gmail.com

<!--
SCREENSHOTS: add real app screenshots here, for example:
![Home](docs/screenshots/home.png)
-->

---

## Features

**Clients and projects**
Add clients with Call, Email and WhatsApp quick actions, notes, and sorting by name, total earned or pending amount. Client and project totals are maintained by Postgres triggers, so they never drift.

**Work log and time**
Log work entries with filters and a Video Stats screen. Each entry has a Start/Stop timer that adds to Hours Worked instead of overwriting it.

**Invoices**
Create a PDF invoice per project (with invoice number and optional payment instructions). Share it through the native share sheet (Email, WhatsApp and more), or copy a private, read-only online invoice link for your client.

**Income and expenses**
Track income and expenses in their original currencies (never auto-converted), see Pending Payments ("Money I Need to Receive"), view analytics and download monthly PDF financial reports.

**Recurring (retainer) invoices**
Mark a client as a retainer (monthly amount, currency, billing day). A new invoice is created automatically once a month, or any time with "Generate Now".

**Late-payment reminders**
Newly overdue invoices trigger a local notification once.

**Reminders and search**
One-time or repeating reminders with priority and local notifications, plus global search across clients, work entries and reminders.

**CSV export and import**
Export clients, work entries, income and expenses as CSV files. Import income from CSV.

**Accounts**
Email/password sign-up with email verification (resend with cooldown), Google Sign-In, forgot/reset password, a 4-screen onboarding flow, and a Profile tab with avatar, default currency, theme (Light/Dark/Auto), change password, logout and delete account.

**Optional: Gym and Diet**
Workouts, routines, exercise library, meal logging, body stats and goals. Turn it on or off in Profile. Turning it off hides the data but never deletes it.

**Optional: AI assistant**
Suggestions and drafts based on fixed task selections and allow-listed aggregate metrics only. No free-text prompts, client details, notes or transaction rows are sent. It requires explicit consent on first use and can be disabled in Profile.

---

## Install the app (Android)

1. Open the [download page](https://worklog-site.netlify.app/download/) on your Android phone.
2. Download the APK.
3. When asked, allow your browser to **Install unknown apps**.
4. Open the downloaded file and install.

To update, download the newer APK and install it over the current app. You do not need to uninstall first.

---

## Tech stack

| Area | Technology |
| --- | --- |
| App | Flutter (Dart), Android only |
| State management | Riverpod, repository pattern |
| Navigation | GoRouter (auth-state-driven) |
| Backend | Supabase (Postgres, Auth, Storage, Realtime, Edge Functions) |
| Website | Static site on Netlify, with Netlify Functions |
| CI/CD | GitHub Actions (website deploy) |

### Architecture notes

- **Rollups live in Postgres, not Dart.** Client and project totals are maintained by triggers in `supabase/schema.sql`. The app never writes those columns directly.
- **Realtime.** Repository `watch*` methods stream from Supabase, including the profile row, so toggling Gym on one device updates every signed-in session.
- **Auth-state-driven routing.** `lib/app/router.dart` redirects in this order: password recovery, signed out, signed in but not onboarded, then normal navigation.
- **Row Level Security (RLS).** Every table has RLS scoping rows to `auth.uid()`. Re-check this after any schema change using the query at the bottom of the V2 migration in `schema.sql`.

---

## Developer setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL Editor:** paste the entire contents of `supabase/schema.sql` (base schema and the V2 section at the bottom) and run it.
3. **Authentication > Providers:** enable **Google** if you want Google Sign-In. You need an OAuth **Web** client ID from Google Cloud Console, and for Android also your app's SHA-1 fingerprint.
4. **Authentication > URL Configuration > Redirect URLs:** add
   - `https://worklog-site.netlify.app/verified/` (signup email confirmation)
   - `io.worklog.app://login-callback/`
   - `io.worklog.app://reset-callback/`
5. **Authentication > SMTP Settings:** connect a real provider (Resend or Brevo) before any public launch. Supabase's built-in sender is limited to 2 emails per hour.
6. **Project Settings > API:** copy the Project URL and the **anon** key.

### 2. Run the app

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-id.apps.googleusercontent.com
```

Without these `--dart-define` values, the app shows a "Connect Supabase" screen instead of crashing.

### 3. Build a release APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-id.apps.googleusercontent.com
```

The APK is created at `build/app/outputs/flutter-apk/app-release.apk`.

### 4. Publish a new release

1. Increase `version` in `pubspec.yaml` (for example `1.0.1+2`). Android will not install an update with the same or lower build number.
2. Build the APK with the **same signing keystore** every time. A different key means existing users cannot update.
3. On GitHub, go to **Releases > Draft a new release**, create a tag such as `v1.0.1`, upload the APK named exactly `app-release.apk`, and publish it as the latest release.

The website download button points to `releases/latest/download/app-release.apk`, so it always serves the newest release.

### 5. Website and Netlify

The `website/` folder and `netlify/functions/` are deployed to Netlify by GitHub Actions on push. The website provides product information, support, the email-verification result page and read-only shared invoices. It does not run the Flutter app in a browser. The Android APK is built and released manually (step 4).

---

## Security

- Never commit secrets: `.env` files, signing keystores (`*.jks`, `*.keystore`), `key.properties`, service-account JSON files, API tokens or the Supabase **service_role** key. These are listed in `.gitignore`.
- The Supabase **anon** key is designed to be public, but only RLS protects your data, so keep RLS enabled on every table.
- Keep `GEMINI_API_KEY` as a Supabase Edge Function secret. Do not put it in Flutter defines, website assets or source control.
- Online invoice links are private token links, not identity checks. Share them only with the intended recipient.
- To enable the AI assistant, deploy the `worklog-assistant` Edge Function and set the secret. Review Google's current terms before enabling it, since free-tier terms may allow submitted content to improve Google products.

Found a security issue? Please email worklog.support@gmail.com instead of opening a public issue.

---

## Known limitations

- Retainer invoice generation and the overdue-invoice check run on the client when the Home screen launches. An optional `pg_cron` schedule is included (commented) at the end of `supabase/schema.sql` if you want them to also run server-side.
- A few polish items are partial: swipe actions on Work Entries, shimmer skeleton loaders (a lightweight placeholder is used today), a recurring-expense flag, and filter chips for client sorting.
- CAPTCHA (Attack Protection) and MFA are Supabase Dashboard settings, not app code. MFA is deferred.
- Android only. There is no iOS or web version of the app.

---

## Folder structure

```
lib/
  app/              router, theme, responsive shell (bottom nav / side rail)
  core/             config, error handling, shared widgets, utils, pdf
  features/
    auth/           sign-up, login, forgot/reset password, Google
    onboarding/     4-screen first-run flow
    profile/        Profile tab, edit profile, change password
    home/
    work/
    clients/
    finance/
    gym/            optional module (toggle in Profile)
    reminders/
    search/
  services/notifications/
android/            Android project
assets/images/      app images
supabase/           schema.sql (base schema + V2 migration) and Edge Functions
website/            public Netlify website
netlify/functions/  serverless functions for the website
.github/workflows/  GitHub Actions workflow(s)
scripts/            helper scripts
docs/               documentation
test/               tests
```

---

## Support

Questions or problems? Visit the [support page](https://worklog-site.netlify.app/support/) or email worklog.support@gmail.com.

- [Privacy Policy](https://worklog-site.netlify.app/privacy/)
- [Terms](https://worklog-site.netlify.app/terms/)
