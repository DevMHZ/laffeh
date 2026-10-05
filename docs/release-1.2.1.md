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
- The Android bundle is version 1.2.1 (11), targets API 36, and passed the public-asset check. SHA-256: `c0f211f5bb506f07731db0e75084ae7085e603cc87de2775ec04f3c18947aed8`.
- The iOS archive is version 1.2.1 (11) and targets iOS 15. Xcode exported and uploaded the signed IPA successfully. SHA-256: `051f26f18a3dd983998f9a52a7abc9b0ec3c688107f7f39cb8b4c8999446c370`.

## Store release

- App Store Connect accepted build 11 with Arabic, English, and French release notes on October 5, 2026 at 16:06 CEST. The [review submission](https://appstoreconnect.apple.com/apps/6802438232/distribution/reviewsubmissions/details/b4e29592-097e-49b9-a2c1-db64d1c64a2c) is **Waiting for Review**. Automatic release after approval is selected. Xcode reported the same nonblocking document-configuration and MapLibre dSYM warnings seen with build 10.
- Google Play accepted the 1.2.1 (11) bundle for the [production track](https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/tracks/production). The 100% rollout in all targeted countries is under **Changes in review** in [Publishing overview](https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/publishing), with automated checks still running when submitted. Managed publishing is off.
