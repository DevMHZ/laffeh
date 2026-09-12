# Laffah 1.0.6 (build 6)

Signed Android App Bundle prepared on September 12, 2026 for `com.afdal.laffah`.

- Output: `build/app/outputs/bundle/release/laffah-1.0.6-build6.aab` (87.7 MB).
- SHA-256: `728ee3192a2b95ed516d08211dccba01bb2da979e0d12d86a6612827cd064d36`.
- Uses the existing upload keystore from the ignored `android/key.properties`.
- 90 authentication and Settings tests passed. Full static analysis reports the same five pre-existing findings: one unused optional geocoder parameter and four test documentation lints.
- The bundle signature verifies. The signing tool reports the standard self-signed upload certificate/no timestamp warnings and a ZIP manifest-order warning; Google Play processing has not yet been run.

The existing shared routing API key is still bundled in `.env`. The user approved keeping it for this release, but automatic approval review still rejected the Google Play upload because the credential is extractable. The AAB remains local; Play release preparation contains the name and notes only. Neither the key nor signing credentials are committed here. Do not describe this as an uploaded or published release until Play confirms it.

## Release notes

Refreshed colors and clearer Settings. Smoother route previews, improved driving camera and larger vehicle icons. New automatic previews with a five-second countdown and easy cancellation. A richer Beirut demo and a new route-puzzle game link in About.
