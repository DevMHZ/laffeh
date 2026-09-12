# Laffah 1.0.6

## iOS build 8 — App Store Connect

- Archived September 12, 2026 with Xcode 26.5: `build/ios/archive/Runner.xcarchive` (209.8 MB).
- Main app `com.afdal.laffah` and share extension `com.afdal.laffah.ShareExtension` both report version `1.0.6`, build `8`.
- Archive verification passed: only the allowlisted public configuration, no private `.env` asset or legacy routing field.
- Command-line IPA export could not locate distribution assets. Xcode Organizer resolved the existing Apple Distribution signing assets and uploaded successfully at 18:34 CEST.
- App Store Connect version 1.0.6 created with release notes in Arabic, English (U.S.) and French. Existing screenshots and listing details retained; automatic release after approval retained.
- Upload accepted with non-blocking warnings: document-opening mode is not explicitly declared, iOS 14 minimum support needs updating before Apple's spring 2027 requirement, and the upstream MapLibre framework has no matching dSYM.
- Build processing completed successfully; build UUID `0c8c0235-324c-4cd1-9834-34f491edadb4`. Attached build 8 to App Store version 1.0.6 and submitted September 12, 2026 at approximately 18:40 CEST. App Store Connect confirmed **1 Item Submitted** and **Waiting for Review**. Automatic release after approval is enabled.
- Review submission: https://appstoreconnect.apple.com/apps/6802438232/distribution/reviewsubmissions/details/80bafba9-f2c8-4350-ae8d-d2ac3ff1a202
- Related web mobile-viewport fix `1995770` is live on production. Map and fixed controls now use the same viewport; responsive checks confirmed no gap above navigation or in Focus mode at 393×740 and 393×840.

## Build 8 — POI imports and map taps

Signed bundle prepared September 12, 2026; not uploaded or submitted yet.

- Output: `build/app/outputs/bundle/release/laffah-1.0.6-build8.aab` (87,712,841 bytes).
- SHA-256: `f5f0545f3d1f46069d59e36f865bf19343e611954158c29b0cd7f64a4e07054a`.
- Package `com.afdal.laffah`, version name `1.0.6`, version code `8`, existing upload keystore.
- Google POI imports follow the new HTML share landing page and bounded redirects, and prefer the business pin over the map camera centre. Sharing and pasting preserve the POI name; share captions do not add extra stops.
- A tap anywhere on the planning map offers Add as a stop / Start the trip here. Labelled places keep their names; unlabeled points show exact coordinates. Existing marker, driving, preview and manual-placement gestures remain separate.
- Tests cover Google/Apple links, redirect loops, off-provider redirects, POI/camera priority, shared captions, pasted rows and first-tap behaviour. A live Dart lookup of the public Coral Basta Maps share resolved to its exact business pin. Simulator tapping unlabeled space displayed the sheet and successfully added a point.
- Static analysis retains only the five pre-existing findings documented below. The bundle configuration verifier passed.
- Google Play now shows the open-testing track paused and build 7 superseded. Build 8 destination is awaiting the owner’s choice; no Play release was changed for this build.

Release notes: Fixed Google Maps business and restaurant link imports. Tap anywhere on the planning map to add a stop or set your departure. Shared places now retain their names and use the correct pin location.

## Build 7 — submission history

Signed Android App Bundle rebuilt on September 12, 2026 for `com.afdal.laffah`.

- Output: `build/app/outputs/bundle/release/laffah-1.0.6-build7.aab` (87,676,858 bytes).
- SHA-256: `f9953c4b0b685685749ab417ddb7ffd8fcf7418f877a4c2008f866535989d5c6`.
- Uses the existing upload keystore from ignored `android/key.properties`; signature verifies.
- 91 mobile tests passed across authentication, Settings and routing access. Three public configuration generator checks passed. Static analysis retains the five pre-existing findings (one geocoder warning and four test documentation lints).
- Backend: 30 mobile access tests and 111 regression tests passed. Production commit `a081916` is live on Render.
- Streamed inspection of every bundle entry confirms the legacy routing key is absent. The private `.env` asset is absent. Only the allowlisted `assets/public.env` ships.

## Routing credential change

Build 7 replaces the privileged shared B2B key with `laffaMobileAppKey`, a newly
generated, intentionally publishable client ID. The new server endpoint
`/api/mobile/optimize` can only calculate routes from supplied coordinates.
Server limits: one vehicle, 1–100 stops, 1–10 seconds of solver search, 128 KiB
JSON, 30 requests/minute, 300/hour and two simultaneous solves. The ID is not
authentication of a trusted device or user and cannot authorize tracking,
B2B/file APIs, accounts or administration. No privileged credential is forwarded
on its behalf. Supabase anon/publishable configuration remains public by design.
The generator rejects service-role keys and excludes the unused Mapbox token.

Existing B2B keys remain server-side for older clients; rotating/revoking those
would require a separate migration. The blocked build 6 is superseded and must
not be uploaded. Build 7 was uploaded successfully through Chrome's native file picker.
Google Play processed and accepted App bundle `7 (1.0.6)`: API levels 24+,
target SDK 36, three ABIs, with ReTrace mapping and native debug symbols.
The bundle was first saved as a production-track draft. On September 12, 2026,
it was also attached from Play's library to the open-testing release
`1.0.6 (7)` and submitted to Google for review. Publishing overview confirmed
**Changes in review**, with exactly one change: **Open testing — 1.0.6 (7) —
Start full rollout**. Managed publishing is off. Google approval is pending;
the production-track draft was not submitted.

The two open-testing errors (no eligible upgrade and no app bundles added or
removed) were caused by the empty testing release. Attaching the accepted
build 7 cleared both errors and Play showed **Ready to release** before
submission. No new binary or version code was needed.

Publishing status: https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/publishing

Open-testing release: https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/tracks/4699064594245287204/releases/1/review

Play draft: https://play.google.com/console/u/0/developers/5891027044453857427/app/4973371552052367519/tracks/4697283739472337143/releases/1/prepare

The live API smoke test returned a valid one-vehicle route for two public Beirut
demo stops. Attempts to request seven vehicles or use the new ID for tracking
and privileged B2B optimization were rejected.

The subsequent web/backend release `9b8a35f` is live. It adds one fleet-wide
Deliver/Pickup/Indifferent preference, phone layouts, and explicit kg·km and
driving tradeoffs. It also fixes the cumulative 2% detour limit and the pickup
carried-load calculation. Validation: 145 backend tests and 13 frontend tests
passed, along with the production frontend build and responsive browser checks.

## Rebuild and verify

```sh
python3 scripts/prepare_public_config.py
flutter build appbundle --release
python3 scripts/verify_public_bundle.py build/app/outputs/bundle/release/app-release.aab
```

## Release notes

Refreshed colors and clearer Settings. Smoother route previews, improved driving camera and larger vehicle icons. Automatic previews with a five-second countdown and easy cancellation. A richer Beirut demo and a new route-puzzle game link in About. Improved mobile routing access.
