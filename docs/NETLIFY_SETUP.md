# WorkLog website and Netlify setup

The public site is built as one deployable folder: marketing and support pages at `/`, account-verification results at `/verified/`, and token-only invoices at `/invoice/?token=…`. The Flutter app is Android-only and is not served from the website; signed APKs are a separate release.

## First-time setup

1. Create a **private GitHub repository** and push this project to its `main` branch. This local folder is not currently a Git checkout, so review and initialize/push it deliberately; do not upload local secrets or signing files.
2. Connect the existing Netlify site (or create a new site) to the repository only if you prefer Netlify’s Git integration. This project instead includes GitHub Actions deployment, so it needs the Netlify site ID and a personal access token stored as GitHub Actions secrets: `NETLIFY_SITE_ID` and `NETLIFY_AUTH_TOKEN`.
3. Add these GitHub Actions variables: `PUBLIC_SITE_URL` (the actual public origin, e.g. `https://worklog.netlify.app`), `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_PUBLISHABLE_KEY`. For compatibility, the workflow also accepts an existing key stored under the older variable name `PUBLIC_SUPABASE_ANON_KEY`. The value itself must be a Supabase publishable/anon client key; never put a secret or service-role key here. The production workflow checks that the URL and key exist before deploying, so it cannot publish an invoice page with blank configuration.
4. Add Netlify environment variables `GMAIL_SMTP_USER`, `GMAIL_SMTP_APP_PASSWORD` (a Google App Password, not the account password), and optionally `SUPPORT_EMAIL` (defaults to `worklog.support@gmail.com`). Set them for the Production deploy context and trigger a new deploy after saving. The app password stays in Netlify settings and is never bundled into the browser code.
5. Set the public site name in Netlify to `worklog` if available. Netlify assigns `worklog.netlify.app`; the team slug `worklog-app` is unrelated. If `worklog` is unavailable, use the assigned URL as `PUBLIC_SITE_URL` and update Supabase redirects to match.
6. If the current Netlify team enforces SSO on every project, make this public marketing site available to visitors without team login. Keep dashboard/team access protected; only the site’s visitor gate should be removed.
7. In Supabase → Authentication → URL Configuration, set Site URL to the public origin and allow the exact redirect `https://worklog-site.netlify.app/verified/` (or the final configured domain). Keep `io.worklog.app://login-callback/` and `io.worklog.app://reset-callback/` for Android auth flows; remove the old `/app/` redirect. The Android app sends signup and resend-verification emails to `/verified/`; keep the confirmation email link as Supabase’s `{{ .ConfirmationURL }}`. If a custom template constructs the URL itself, use `{{ .RedirectTo }}` for its redirect destination rather than hard-coding `{{ .SiteURL }}`. Otherwise the button may confirm the email but send people to an old or incorrect page.

## Local checks

Use Node.js 22.12 or newer. From the repository root, run `npm ci`, then `npm ci --prefix website`. Run `npm run test:contact`, `flutter analyze`, `flutter test`, and `npm run build`. The combined build writes the deploy folder to `website/dist`; do not edit generated output by hand. For local website-only iteration use `npm run dev --prefix website`.

The support form validates input, has a honeypot and short per-instance IP throttle. Netlify function instances are ephemeral; for a public launch with heavier traffic, use a persistent rate limiter (for example Netlify Blobs/Turnstile) and SMTP delivery monitoring.

## Deploys and upgrades

Open a pull request to run checks and create a Netlify Deploy Preview. Merge approved changes to `main` to publish the marketing site. Netlify keeps prior deploys available for rollback. If the deploy steps are skipped, verify both GitHub secrets are configured. Keep preview deployments private if they contain non-public app features or data.

Every approved site/code update is a website deploy. It does not publish a new Android APK. Android release/versioning and signing setup are described in [APP_RELEASES.md](APP_RELEASES.md). Never upload `.env`, SMTP passwords, Supabase service-role keys or Android signing keys to GitHub.

Before public launch, replace the draft Privacy and Terms wording with the operator’s legal identity, jurisdiction and confirmed data retention practices. Verify support email delivery, Android signup/confirmation, invoice valid/invalid tokens, mobile layout and keyboard navigation. The invoice lookup is intentionally restricted to the existing `get_public_invoice(uuid)` RPC.
