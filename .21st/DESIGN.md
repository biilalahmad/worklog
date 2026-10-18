<!-- Project-aware design notes; .21st/design.json is the machine-readable source. -->
# WorkLog Design Context

## Product

WorkLog is a freelancer work-log and productivity app. The public Astro site
explains the Android app, handles email-verification results, and shares
read-only invoices. Account registration and app login stay in the Android app.

## Visual system

- Palette: navy `#173B61`, blue `#2F6F9F`, sky `#73BAF0`, pale `#F2F7FB`, white.
- App and auth forms: bundled Poppins. Public website: self-hosted Poppins in regular,
  medium and bold weights; no external font request is needed.
- The marketing site supports a persisted light/dark preference; the app has its own light and dark themes.
- Use the supplied WorkLog logo, spacious spacing, soft blue-tinted card shadows,
  and rounded controls.
- Motion is subtle and purposeful; always respect `prefers-reduced-motion`.
- Homepage hero accents use inline SVG stars with gentle twinkle, drift, and pointer parallax; app previews loop right automatically and also provide swipe plus wrapping previous/next controls. The carousel pauses for hover, focus, and direct interaction, and respects reduced-motion preferences.
- Interior page heroes use several small, softly animated inline SVG clouds; the homepage hero keeps its distinct animated star field. Keep the icon-only light/dark toggle visible in the navbar at every breakpoint. Center section/page introductions on desktop and tablet, except keep the support introduction left-aligned; leave the existing mobile composition intact.
- Replace the homepage solution and download update-section spotlight gradients with soft, animated inline SVG clouds; keep the homepage FAQ title centered, outline the hamburger with a circular stroke, and show a gently moving sun only in the homepage hero in light mode.
- Save the selected website theme in a first-party preference cookie. Submit the support form through Netlify Forms using URL-encoded fields and the existing honeypot.

## Implementation

- Use existing Astro layouts, components, and CSS before adding dependencies.
- Prefer free, native HTML/CSS/SVG primitives over paid UI packages.
- Preserve mobile responsiveness, visible focus, keyboard navigation, and clear
  loading, success, and error states.
- Do not invent pricing or advertise an APK until a signed release is available.

