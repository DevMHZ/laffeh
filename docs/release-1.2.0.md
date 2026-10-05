# Laffa 1.2.0 — build 10

Release status on October 3, 2026: Android is active in production; iOS build 10 is **Waiting for Review** in App Store Connect.

## Changes

- Drivers can receive, open and acknowledge trips dispatched from the webapp. The inbox shows sender, company, time and unread state, and supports the contact numbers carried in the `.laffa` trip.
- The mobile app fetches its public account-service configuration from the API on launch, allowing the planned account migration after the new app version is available.
- Long-distance and multi-day routes are allowed from mobile.

## Validation

- Focused dispatch/account-configuration tests passed; release Android bundle built, signature verified, and public-bundle check passed (no private environment or legacy key).
- Full Flutter suite: 661 passed, 11 failed. The failures are screenshot/golden comparisons with 3–10 differing pixels; they have not been rebaselined or treated as functional passes.
- Android version 1.2.0 (10), minimum API 24, target API 36. Bundle: `build/app/outputs/bundle/release/laffah-1.2.0-build10.aab`.
- Android bundle SHA-256: `51f11ff8683cb8218868d7c9ac3547f8614f7d17a1930f85c803cb54bbb3d8aa`.
- iOS 1.2.0 (10) archive: `build/ios/archive/Runner.xcarchive`. Apple Distribution certificate was created on this Mac with owner approval, and Xcode Organizer reports **Uploaded with warnings**. The warnings concern document-opening configuration and the upstream MapLibre framework dSYM, as with the previous release; they did not prevent upload.

## Submission

- Google Play now shows production release 1.2.0 (10) as **Active**, with 178 countries/regions. Managed publishing is off. [Production track](https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/tracks/production).
- App Store Connect processed build 10, attached it to version 1.2.0 with Arabic, English and French release notes, and accepted the review submission at 02:06 CEST on October 3. Status: **Waiting for Review**. Automatic release after approval is selected. [Review submission](https://appstoreconnect.apple.com/apps/6802438232/distribution/reviewsubmissions/details/93cf6ba2-973f-4e26-ae23-b551b64f94f1).

## Account cutover

The owner authorized the early Hostinger account cutover on October 3 while the public iOS release remained in App Store review (TestFlight users have build 10). A fresh managed-Supabase export was restored into the independent Hostinger stack. All 29 account credential fingerprints and app-data fingerprints matched; isolated auth/RLS/route/dispatch tests and a live API dispatch test passed. The live account-config endpoint now directs build 10 to `https://auth.afdal.tech`. Managed Supabase is retained read-only for rollback; older iOS versions still point there and must update to regain saved-route writes. A one-time off-VPS backup and tested daily on-VPS backup timer exist; Hostinger's included provider backup cadence is weekly. Recurring independent off-server backups and restore monitoring remain to be configured.
