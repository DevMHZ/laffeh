# Laffa 1.1.1 — build 9

Release prepared from branch `V1.1.1`, source commit `e112d9f`.

## Changes

- Smoother route previews and transitions between 2D and 3D.
- Improved navigation accuracy and stop transitions, with clearer delivery actions.
- Clearer offline and location-startup feedback.
- Fixed Google Maps place imports to preserve names and correct map pins.

## Validation

- 74 authentication tests passed.
- 55 focused navigation, camera, simulation, shared-map and offline tests passed.
- Static analysis: no errors; one existing unused-parameter warning, two deprecated-member notices and four test documentation notices.
- Public client configuration generated with the existing allowlist.
- Android bundle and iOS archive verified: public configuration only; private `.env` and legacy routing key excluded.
- Android signature verified. Version name 1.1.1, version code 9.
- iOS app and share extension both carry 1.1.1 (9); deployment target iOS 15.0.
- Android bundle: `build/app/outputs/bundle/release/laffah-1.1.1-build9.aab`
- Android SHA-256: `bbaa850c04c834bab1bbb27b3c5e4281f8550edb8df447bbe11eca8d113bd428`.

## Submission

Both stores accepted the submission on September 24, 2026.

- Apple: **Waiting for Review**, submitted at 01:29 CEST. Version 1.1.1, build 9. Automatic release after approval retained.
- Apple build UUID: `4c3d6317-61c8-43b1-8c94-05fe9d8ffb04`.
- Apple submission: https://appstoreconnect.apple.com/apps/6802438232/distribution/reviewsubmissions/details/5eb43b87-85d1-4a2b-b9f1-16c7c30bf11b
- Uploaded through Xcode Organizer. Non-blocking warnings: document-opening configuration and missing upstream MapLibre dSYM.
- Google Play: **Changes in review**, production release 1.1.1 (9), full rollout. Automated quick checks still running at acknowledgement; review begins automatically after they pass. Managed publishing remains off.
- Google Play: https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/publishing
- Android upload completed using Chrome's native file picker. Bundle accepted, target SDK 36, minimum API 24, existing upload signature.
- Both stores have release notes in Arabic, English and French. Existing listing details and screenshots retained.
