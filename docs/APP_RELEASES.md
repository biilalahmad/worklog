# WorkLog Android release and update guide

The Android app is not published yet: the Android application ID is still `com.example.freelance_tracker`, and the release build currently falls back to the debug signing key. Do not publish a public APK until both are finalized.

## Before the first public APK

1. Choose a permanent reverse-domain application ID (for example, a domain you control). Change the Gradle `applicationId` and Android namespace consistently before the first release. Do not copy the example unless it is actually yours.
2. Create a private Android upload/release keystore, store its password and alias outside the repository, and keep at least one secure encrypted backup. Configure Gradle release signing from a local ignored `key.properties` file or CI secrets. Never commit the keystore or its passwords. Losing/changing the signing key can prevent users from installing an update over their existing app.
3. Test a release-signed APK on a clean device and over the current development app. Check login, storage, deep links, notifications, permissions and data migration. Decide what data/account privacy disclosures are needed before distribution.
4. Only then add a versioned APK and short release notes under the website’s download assets; change the Download page to expose the real file and checksum/version.

## Each release

Flutter reads the human-readable version and Android build number from the root `pubspec.yaml` entry, currently `0.5.0+1`. Bump the version before each public release, e.g. `0.5.1+2` or `0.6.0+3`; the portion after `+` becomes Android `versionCode` and must increase every time. Keep the application ID and signing key unchanged. Build and verify with `flutter build apk --release`, inspect the signature with Android build tools, install over the previous APK and confirm user data remains available. Then attach the APK, checksum and notes to the release and update the website Download link.

When users install a newer APK with the same application ID and signing certificate, Android updates the existing app in place; they normally do **not** need to uninstall it, and app-private data remains. Users still need to download and approve each direct APK update themselves. For automatic store-managed updates, publish through Google Play under the same application ID/signing lineage. Website changes deploy separately and do not require a new APK.
