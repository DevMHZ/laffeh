# Laffa 1.2.1 — build 11

## Changes

- Route address search and autocomplete use the Google-backed mobile API while its quota is available, then fall back to the existing search providers.
- Location permission and the first GPS fix can be retried without restarting the app. A persistent, clearer recovery notice explains how to enable location or reopen the app if needed.
- The startup animation gives way to the ready app with a fade, even when loading finishes early.
- On the initial empty map, the location and 3D controls sit above the address entry panel. Other map states retain their existing layout.
- The dispatch and account-configuration work prepared for build 10 is included in this source release.

## Validation

- `flutter analyze --no-fatal-infos --no-fatal-warnings` passed (one existing warning and informational notices).
- Focused Google places, location recovery, splash, and empty-map layout tests passed.
- The full Flutter suite reported 669 passes and 12 failures. Most failures are small screenshot/golden differences. Three existing preview-camera tests compare an easing call with a motion writer that currently uses direct camera movement; they remain unresolved and should be reviewed before rebaselining.
- The Android bundle is version 1.2.1 (11), targets API 36, and passed the public-asset check. The iOS archive is version 1.2.1 (11) and targets iOS 15.

## Store release

- App Store Connect and Google Play production drafts were created with Arabic, English, and French release notes.
- Record upload and submission outcomes here after store processing.
