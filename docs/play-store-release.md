# Laffah — Google Play release guide

Everything needed to take the app from this repo to a Play Console upload.

| Fact | Value |
|---|---|
| Package name (`applicationId`) | `com.afdal.laffah` — **permanent**, can never change after the first release |
| Current version | `1.0.0+1` (`versionName+versionCode` in `pubspec.yaml`) |
| `minSdk` / `targetSdk` | 24 / 36 (Flutter defaults — meets Play's current target-API requirement) |
| Suggested category | Maps & Navigation |
| Contains ads | No |
| Privacy policy URL | `https://www.afdal.tech/policies/laffa-app.html#privacy-policy/en` |
| Terms URL | `https://www.afdal.tech/policies/laffa-app.html#terms-of-service/en` |
| Account deletion URL | `https://www.afdal.tech/policies/laffa-app.html#account-deletion/en` |

---

## 1. Create the upload keystore (you must do this — not Claude)

The keystore and its passwords are credentials; generate them yourself and store
them in your password manager. **If you lose this file you can never update the
app on Play again.**

There is no system Java on this machine (`keytool` alone fails with "Unable to
locate a Java Runtime"), so call the JDK that Android Studio ships — the same one
`flutter doctor` reports and Gradle already builds with:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v -keystore ~/laffah-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It prompts for a store password, then a name/org (any values — they are not shown
on Play), then the key password (pressing Enter reuses the store password).

Then create `android/key.properties` (gitignored — never commit it):

```properties
storeFile=/Users/<you>/laffah-upload.jks
storePassword=<the store password you just set>
keyAlias=upload
keyPassword=<the key password you just set>
```

Back up `laffah-upload.jks` somewhere durable and offline. Also enable **Play App
Signing** in the console (the default) so Google holds the app signing key and
this one is only your *upload* key — that way a lost upload key can be reset by
Google support instead of ending the app's life.

Without `key.properties`, `flutter build` still succeeds but signs with the debug
key and prints a warning; that artifact is rejected by Play.

## 2. Build the bundle

```bash
flutter clean && flutter pub get && flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**On size:** the `.aab` is ~73 MB because it carries native libraries for three
ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64` — 84 MB of `.so` before compression).
Play splits per device, so the actual user download is roughly a third of that.
Nothing to fix; just don't be alarmed by the number. Dropping `x86_64` (emulator
only) would shrink it further if you ever want to.

## 3. Verify before every upload

```bash
flutter analyze && flutter test test/auth/
```

`versionCode` must increase on every upload — bump the number after `+` in
`pubspec.yaml` (`1.0.0+1` → `1.0.0+2`, …).

---

## 4. Play Console — Data safety form

Answer it from what the app actually does. Collected, **not shared** with third
parties, **encrypted in transit** (HTTPS/Supabase), and users **can request
deletion** (in-app: Settings → Delete account; on the web: the account-deletion
URL above).

| Data type | Collected | Required? | Purpose |
|---|---|---|---|
| **Phone number** (Personal info) | Yes | Required | Account creation & sign-in — it *is* the credential |
| **Name** (Personal info) | Yes | Required | Onboarding profile (`full_name`) |
| **Other info** — company name, usage reasons | Yes | Required | Onboarding profile / understanding usage |
| **Precise location** (Location) | Yes | Optional | App functionality: route planning, "my location", drive mode |
| **Device or other IDs** | Yes | Required | A random per-install UUID (`device_id`) that keys the last-known location row |

Notes for the reviewer/questionnaire:

- Location is collected **only while the app is open** (foreground). There is no
  background location, no `ACCESS_BACKGROUND_LOCATION`, and no foreground
  service — so the background-location declaration form does not apply.
- Only the **latest** location is retained: one row per device in
  `device_locations`, overwritten on each launch. It is not a location history.
- Passwords are never stored by the app or in its database — they live only in
  Supabase Auth.
- Target audience is **not** children.

## 5. Play policy requirements already satisfied in-app

- **Account deletion** (mandatory for any app with accounts): Settings →
  Delete account, with an explicit confirmation listing what gets removed, backed
  by the `delete_my_account()` RPC. The web equivalent is the account-deletion
  URL above.
- **Policy consent at sign-up**: the "create account" step requires ticking a
  consent box that links to the published privacy policy and terms; the accepted
  version is recorded on-device *and* server-side
  (`profiles.terms_version` / `terms_accepted_at`).
- **Policies reachable in-app**: Settings → Legal, and from the welcome screen.

## 6. Store listing checklist

- App name: **Laffah** (matches `android:label`)
- Short + full description in **en / ar / fr** — the app itself ships all three
- Screenshots: phone (min 2), from the planner, the route summary, and drive mode
- Feature graphic 1024×500
- App icon 512×512 (the launcher icon is already a custom adaptive icon)
- Privacy policy URL → the field in *Store presence → App content*
- New personal developer accounts must run **closed testing with 12 testers for
  14 days** before production access. Organisation accounts are exempt. Plan for
  this before promising a launch date.

---

## Known gaps / follow-ups (not blockers)

1. **`.env` ships inside the bundle.** It is bundled as a Flutter asset, so
   anyone who downloads the app can extract `base/assets/flutter_assets/.env`
   and read every key in it:
   - `SUPABASE_ANON_KEY` — fine, it is public by design and guarded by RLS.
   - `MAPBOX_ACCESS_TOKEN` — restrict it to this app / rotate it if it is a
     secret token; an unrestricted token can be billed against by anyone.
   - `AI_ROUTE_API_KEY` — **this is a real secret and is currently extractable.**
     Move the call behind your own backend, or issue per-app keys with limited
     scope, before a public launch.
   `.env` is gitignored, so any CI that builds the AAB must inject it.
2. **iOS / macOS / Windows / Linux still use `com.example.laffeh`.** Only Android
   was renamed (Play is the target). Change the iOS bundle id before an App
   Store submission — it affects provisioning profiles, so do it deliberately.
3. **Dead assets in the repo:** the `.glb` models and `assets/Laffa Avatars.html`
   are not listed in `pubspec.yaml`, so they do not ship in the bundle — they are
   only repo weight left from the 3D spike. Safe to delete when convenient.
4. **Golden tests** (`splash`, `loader`, animations) are stale from earlier UI
   work and fail on pixel diffs. Refresh with
   `flutter test --update-goldens` once the current rendering is what you want.
