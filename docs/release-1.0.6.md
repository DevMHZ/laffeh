# Laffah 1.0.6 (build 7)

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
not be uploaded. Build 7's Google Play name and notes are saved; bundle upload
and processing are pending verification.

## Rebuild and verify

```sh
python3 scripts/prepare_public_config.py
flutter build appbundle --release
python3 scripts/verify_public_bundle.py build/app/outputs/bundle/release/app-release.aab
```

## Release notes

Refreshed colors and clearer Settings. Smoother route previews, improved driving camera and larger vehicle icons. Automatic previews with a five-second countdown and easy cancellation. A richer Beirut demo and a new route-puzzle game link in About. Improved mobile routing access.
