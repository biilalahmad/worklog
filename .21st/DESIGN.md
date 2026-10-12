<!-- Project-aware design notes; .21st/design.json is the machine-readable source. -->
# WorkLog Design Context

## Product

WorkLog is a freelancer work-log and productivity app. The public Astro site
explains the Android app, handles email-verification results, and shares
read-only invoices. Account registration and app login stay in the Android app.

## Visual system

- Palette: navy `#173B61`, blue `#2F6F9F`, sky `#73BAF0`, pale `#F2F7FB`, white.
- Main app body: Inter. Display: Helvetica Neue / Helvetica with Inter and Arial fallbacks.
- Auth forms: bundled Poppins. Public website: self-hosted Poppins in regular,
  medium and bold weights; no external font request is needed.
- The marketing site is light; the app supports both light and dark themes.
- Use the supplied WorkLog logo, spacious spacing, soft blue-tinted card shadows,
  and rounded controls.
- Motion is subtle and purposeful; always respect `prefers-reduced-motion`.

## Implementation

- Use existing Astro layouts, components, and CSS before adding dependencies.
- Prefer free, native HTML/CSS/SVG primitives over paid UI packages.
- Preserve mobile responsiveness, visible focus, keyboard navigation, and clear
  loading, success, and error states.
- Do not invent pricing or advertise an APK until a signed release is available.

