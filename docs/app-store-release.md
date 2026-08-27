# Laffah — App Store (iOS) release guide

Everything needed to take the app from this repo to an App Store submission.
Companion to [play-store-release.md](play-store-release.md); anything already
answered there (data safety, account deletion, `.env` exposure) is repeated here
only where Apple asks it differently.

**State of the iOS build, verified on this repo (2026-08-17):**

| Fact | Value |
|---|---|
| `flutter build ios --release --no-codesign` | ✅ succeeds — `Runner.app`, 47.9 MB |
| `flutter analyze` | ✅ no issues |
| `flutter test` | 180 pass / 10 fail — all stale goldens, failing identically before these changes |
| Xcode / Flutter | 26.6 (build 17F113) / 3.41.9 stable, Dart 3.11.5 |
| Bundle id | ✅ `com.afdal.laffah` — verified in the built binary |
| Deployment target | iOS 14.0 (`Podfile`, `project.pbxproj`) — fine |
| Device family | ✅ `1` — iPhone only (`UIDeviceFamily => [1]`) |
| App icon | ✅ full set, 1024×1024 with `hasAlpha: no` |
| Signing team | ❌ none set — **you do this in Xcode**, see §3.1 |
| Share-from-WhatsApp on iOS | ✅ ships as a Share Extension — reached through Maps, not from WhatsApp directly, see §2.4 |
| Cleartext HTTP | ✅ none — no ATS exceptions needed |
| Version | `1.0.3+3` → `CFBundleShortVersionString` 1.0.3, `CFBundleVersion` 3 |

---

## 0. The short version

Everything in §2 and §3.4 is **already applied in this repo**. What is left is
work that happens in Apple's tools and your accounts:

1. Apple Developer Program membership + App Store Connect app record (§1)
2. Signing in Xcode — the one remaining project change (§3.1)
3. Answer App Privacy + export compliance (§4)
4. `flutter build ipa` → upload → TestFlight (§5)
5. Store listing, screenshots, review notes (§6, §7)
6. Submit (§8)

Realistic timeline: **half a day of your time**, plus 1–3 days waiting on Apple
(account verification is the long pole if the account doesn't exist yet).

---

## 1. Apple side — do this first, it has the longest lead time

### 1.1 Membership

- **Apple Developer Program**, 99 USD/year, at <https://developer.apple.com/programs/>.
- **Individual vs Organization.** An Organization account shows *Afdal* as the
  seller and needs a **D-U-N-S number** (free, but issuance can take days to
  weeks). An Individual account shows your personal legal name as the seller and
  is approved in hours. For a company-branded app, Organization is the right
  answer — start the D-U-N-S lookup today.
- Enrolment is paid with a card and verified by Apple; you do this yourself, not
  from this repo.

### 1.2 Agreements

In App Store Connect → **Business**: accept the *Apple Developer Program License
Agreement*. Because Laffah is free with no in-app purchases, the **Paid
Applications agreement, tax forms and banking details are not required**. If you
ever add a subscription, that changes.

### 1.3 Register the bundle id

Either let Xcode create it during automatic signing, or do it explicitly at
Certificates, Identifiers & Profiles → Identifiers → **App IDs**:

- Bundle id: `com.afdal.laffah` (see §2.1)
- Capabilities to enable: **App Groups** (needed by the Share Extension, §2.4).
  Nothing else — no push, no associated domains, no HealthKit.

Also register the extension id `com.afdal.laffah.ShareExtension` and the group
`group.com.afdal.laffah`.

### 1.4 Create the app record

App Store Connect → **Apps → +**:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | `Laffah` (must be unique across the whole store — check availability early) |
| Primary language | Arabic (or English — pick the one your main market reads) |
| Bundle ID | the identifier from §1.3 |
| SKU | any internal string, e.g. `laffah-ios-001` |
| User access | Full |

The name is reserved the moment you create the record, which is another reason
to do this before anything else.

---

## 2. Repo work — all of this is done

Recorded here because the *why* matters at review time and when someone later
wonders why iOS differs from Android.

### 2.1 Bundle identifier ✅

`ios/Runner.xcodeproj/project.pbxproj` carried the Flutter template id
`com.example.laffeh`, which Apple rejects outright. It is now
**`com.afdal.laffah`** across all three configurations, with the test target at
`com.afdal.laffah.RunnerTests`, and `CFBundleURLName` in `Info.plist` corrected
from the stale `tech.afdal.laffeh` to the same id.

Matching Android is deliberate: the two stores are separate namespaces, and one
id across platforms keeps deep links, analytics and support conversations sane.

**This id is permanent after the first upload.** Verified in the built binary:
`CFBundleIdentifier => "com.afdal.laffah"`.

### 2.2 Two unused plugins removed ✅

`file_picker` and `permission_handler` were declared in `pubspec.yaml` but **not
imported anywhere in `lib/` or `test/`**. They still compiled into the IPA, and
both are classic App Store rejection sources:

- `file_picker` pulled in `DKImagePickerController` → `DKPhotoGallery` →
  `SDWebImage` + `SwiftyGif`, i.e. **photo-library APIs**. Apple's automated scan
  returns *ITMS-90683: Missing purpose string — NSPhotoLibraryUsageDescription*
  for a binary that links them, and the plist has no such key.
- `permission_handler_apple` compiles **every** permission handler unless
  restricted with `PERMISSION_*` macros in the Podfile — camera, contacts,
  microphone, motion, tracking. Same rejection class, several times over.

Both are gone from `pubspec.yaml`. The pod count dropped from 15 to 9, and
`ios/Pods/` was wiped and reinstalled, which also cleared the stale `GoogleMaps`
and `Google-Maps-iOS-Utils` directories left over from an old experiment.

Note that `pod install` needs a UTF-8 locale on this machine or it dies with
`Unicode Normalization not appropriate for ASCII-8BIT`:

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install --project-directory=ios
```

`flutter build` sets this itself, so only manual `pod` invocations are affected.

### 2.3 Info.plist ✅

- **`ITSAppUsesNonExemptEncryption = false`** added. Laffah only uses HTTPS and
  the OS's own crypto, which is exempt from export compliance. Without this key,
  App Store Connect asks the encryption question on *every* build; with it,
  uploads go straight to TestFlight.
- **`google.navigation` removed** from `CFBundleURLTypes`. That scheme is an
  Android intent convention — declaring another vendor's scheme as one your app
  *serves* does nothing on iOS and invites reviewer questions. `laffeh` stays,
  which is what the policy deep links use.
- **`UISupportedInterfaceOrientations~ipad` removed** — dead weight now that the
  app is iPhone-only (§3.4).
- `LSApplicationQueriesSchemes` keeps `whatsapp`: the support and
  forgot-password flows still hand off to WhatsApp, and iOS silently fails
  `canLaunchUrl` for undeclared schemes.

### 2.4 WhatsApp import — how it reaches iOS ✅

On Android, `receive_sharing_intent` works off `<intent-filter>`s already in the
manifest: the driver shares a WhatsApp location straight to Laffah. **iOS has no
such one-step route, and never will** — tapping a location in WhatsApp for iOS
opens WhatsApp's own map with a hard-coded "Select an action" sheet listing
Maps, Google Maps and Waze. That list is WhatsApp's, built from schemes in
*their* Info.plist, and no third-party app can join it.

What does work is the hop through a map app, which is what ships:

> WhatsApp → tap the location → **Open in Maps** (or Google Maps) → the share
> button there → **Laffah**.

Five taps instead of two, but native, and the payload parses on arrival.

The pieces:

- **`ios/Share Extension/`** — the target itself. `ShareViewController` is a
  bare subclass of `RSIShareViewController`; everything else is configuration.
  Its `NSExtensionActivationRule` accepts **text and one web URL only** — no
  `PHSupportedMediaTypes`, no image/video/file rules, so Laffah stays out of
  photo share sheets and out of ITMS-90683 territory (§2.2).
- **App Group `group.com.afdal.laffah`** — declared in
  `ios/Runner/Runner.entitlements` and `ios/Share Extension/Share Extension.entitlements`,
  and named by the `CUSTOM_GROUP_ID` build setting on both targets, which the
  two Info.plists read as `AppGroupId`. The extension writes the shared link
  there; the app reads it.
- **`ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)`** in the app's `CFBundleURLTypes` —
  the private scheme the extension uses to reopen the app. Never typed by a
  user.
- **`ios/Share Extension/{Debug,Release,Profile}.xcconfig`** — mirror
  `ios/Flutter/*.xcconfig` so the extension inherits `FLUTTER_BUILD_NAME` and
  `FLUTTER_BUILD_NUMBER`; the App Store rejects an extension whose version does
  not match the app. They also pin `OTHER_LDFLAGS` to
  `-framework "receive_sharing_intent"`: CocoaPods' `inherit! :search_paths`
  otherwise links **every** pod into the extension, MapLibre and geolocator
  included, which is both slow to launch and a purpose-string liability.
- **Build phase order** — `Embed Foundation Extensions` must sit *above*
  Flutter's `Thin Binary`, or the extension can't find the framework it imports.

Two behaviours worth knowing before you touch this again, both verified on the
simulator:

- `APPLICATION_EXTENSION_API_ONLY` must stay at its default `YES`. Setting it to
  `NO` — tempting, since receive_sharing_intent reaches `UIApplication` through
  the responder chain — makes the build system refuse the target outright.
- **A share that launches the app is reported twice** by the plugin: once via
  `getInitialMedia`, then again on the live stream ~20 ms later, same payload
  both times. Each one would add a stop.
  [share_intent_handler.dart](../lib/core/utils/share_intent_handler.dart) drops
  the repeat. It also drops the `ShareMedia-…` URL that `app_links` reports in
  parallel, which would otherwise be geocoded as if it were an address.

No `SceneDelegate` work is needed: Flutter's own `FlutterSceneDelegate` forwards
`scene:openURLContexts:` to plugins that only implement the old
`application(_:open:options:)`, on cold and warm starts alike.

What the extension receives is a *link*, and the two map apps disagree on its
shape, so [link_parser.dart](../lib/core/utils/link_parser.dart) and
[map_link_resolver.dart](../lib/core/utils/map_link_resolver.dart) both learned
new formats: Apple Maps shares `https://maps.apple/p/<id>` — a bare `maps.apple`
host, no `.com` — which redirects to `maps.apple.com/place?coordinate=lat,lng`.
Google Maps shares the familiar `maps.app.goo.gl` short link, or the
`/maps/@lat,lng,17z` URL when shared out of Safari. Covered by
[shared_map_link_test.dart](../test/route_planner/shared_map_link_test.dart).

Worth knowing: the Android `https://maps.google.com` intent filters still have
**no iOS equivalent** — Universal Links require a domain you control, and you
can't claim Google's. Laffah can be shared *to*, never opened *from* a map link.

### 2.5 Localized permission strings ✅

`NSLocationWhenInUseUsageDescription` was Arabic-only, so English and French
users saw an Arabic system dialog at the most sensitive moment in the app.

`ios/Runner/{ar,en,fr}.lproj/InfoPlist.strings` now carry the location purpose
string and the display name per language, registered in the Xcode project as a
proper variant group (with `ar` and `fr` added to `knownRegions`), and
`CFBundleLocalizations` in `Info.plist` reports all three. Verified in the built
`.app`: `ar.lproj`, `en.lproj`, `fr.lproj` are all present with the right text.

The display name is `Laffah` in all three. If you'd rather Arabic devices show
**لفّة** on the home screen, change `CFBundleDisplayName` in `ar.lproj` — the
system supports it, it just diverges from the Android label and the store name.

`NSLocationAlwaysAndWhenInUseUsageDescription` is **not** needed:
[location_utils.dart](../lib/core/utils/location_utils.dart) and
[location_ping_service.dart](../lib/core/services/location_ping_service.dart)
only ever accept `whileInUse`/`always` that the user already granted, and never
request "always". Keep it that way — background location triggers a much harsher
review.

---

## 3. Xcode configuration

### 3.1 Signing

Open `ios/Runner.xcworkspace` (**not** the `.xcodeproj`). Runner target →
Signing & Capabilities:

- ✅ Automatically manage signing
- Team: your Afdal team
- Bundle Identifier: `com.afdal.laffah`

Xcode creates the *Apple Distribution* certificate and the App Store provisioning
profile for you. Note that `project.pbxproj` currently pins
`CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` (lines 476, 599, 656) —
automatic signing overrides this for archives, but if a distribution build ever
complains about the identity, that's where it comes from.

Repeat for the `Share Extension` target (`com.afdal.laffah.ShareExtension`).
Both targets need the **App Groups** capability with `group.com.afdal.laffah`;
the entitlements files already declare it, so Xcode only has to provision it.

### 3.2 Version numbers

`pubspec.yaml` `version: 1.0.3+3` feeds `CFBundleShortVersionString` and
`CFBundleVersion` through `Generated.xcconfig` — don't set them in Xcode.

- `1.0.3` is fine as a first App Store version (nothing requires 1.0.0).
- **Every upload needs a higher build number**, even a rejected one. Bump the `+N`.

### 3.3 Capabilities you do *not* need

No push notifications, no background modes, no associated domains, no HealthKit,
no in-app purchase. Adding capabilities you don't use is a review flag — leave
them off.

### 3.4 iPhone only ✅

`TARGETED_DEVICE_FAMILY` was `"1,2"` — a claim of iPad support that would have
meant App Review testing on iPad, a required set of 13" iPad screenshots, and a
visible mismatch between `SystemChrome.setPreferredOrientations([portraitUp])` in
[main.dart:21](../lib/main.dart#L21) and an `Info.plist` advertising all four
iPad orientations.

It is now `"1"` in all three configurations, confirmed in the built binary as
`UIDeviceFamily => [1]`. Adding iPad later is a normal feature release; dropping
a device family after shipping is the painful direction.

---

## 4. Privacy & compliance

### 4.1 App Privacy questionnaire (App Store Connect → App Privacy)

Same truth as the Play data-safety answers, in Apple's vocabulary. Declare
**"Data Not Used to Track You"** for everything — there is no ad SDK, no
cross-app tracking, no third-party analytics in `pubspec.yaml`.

| Apple data type | Collected | Linked to user | Purpose |
|---|---|---|---|
| **Phone Number** (Contact Info) | Yes | Yes | App Functionality — it *is* the sign-in credential |
| **Name** (Contact Info) | Yes | Yes | App Functionality — onboarding profile |
| **Other User Content / Other Data** — company name, usage reasons | Yes | Yes | App Functionality |
| **Precise Location** | Yes | Yes | App Functionality — route planning, "my location", drive mode |
| **Device ID** | Yes | Yes | App Functionality — random per-install UUID keying the last-known-fix row |

Points a reviewer may probe, all defensible:

- Location is **foreground only**. No background modes, no `always` request.
- Only the **latest** fix is retained: one upserted row per device in
  `device_locations`, not a history.
- Passwords never touch the app's database — Supabase Auth holds them.
- No data is sold or shared with third parties.

### 4.2 Privacy manifest (`PrivacyInfo.xcprivacy`)

Third-party requirement is already satisfied — every pod that needs one ships it
(MapLibre, share_plus, url_launcher_ios, app_links, geolocator_apple,
shared_preferences_foundation, and the Flutter engine itself).

Adding an **app-level** `PrivacyInfo.xcprivacy` to the Runner target is
recommended, not strictly required, since the Dart/Swift code here doesn't call
required-reason APIs directly. If you add one, declare `NSPrivacyTracking =
false`, an empty `NSPrivacyTrackingDomains`, and mirror the table above in
`NSPrivacyCollectedDataTypes` — keeping it consistent with §4.1 is the point.

### 4.3 Export compliance

`ITSAppUsesNonExemptEncryption = false` (§2.3). HTTPS-only apps qualify for the
exemption; this is a declaration you're making, so it should stay true — if you
ever add your own crypto, revisit it.

### 4.4 Account deletion — already satisfied

Apple 5.1.1(v) requires in-app deletion for any app that creates accounts.
Settings → Delete account (`deleteAccount` in
[service_locator.dart:264](../lib/core/di/service_locator.dart#L264)) with an
explicit confirmation sheet listing what is removed. Point the reviewer at the
exact path in the review notes (§7).

### 4.5 Sign in with Apple — not required

Guideline 4.8 only bites when you offer *third-party* social login (Google,
Facebook…). Laffah uses its own phone + password against Supabase, so no Apple
sign-in obligation. If you ever add Google sign-in, Sign in with Apple becomes
mandatory alongside it.

### 4.6 Map attribution

MapLibre renders OSM/Mapbox tiles. Keep the default attribution control visible —
both OSM's ODbL and Mapbox's ToS require it, and it costs you nothing at review.

---

## 5. Build and upload

### 5.1 Pre-flight

```bash
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter analyze
flutter test test/auth/
```

`.env` is gitignored but **bundled as a Flutter asset** — make sure the real one
is present before archiving, or the app ships with no Supabase/Mapbox config.

### 5.2 Build the IPA

```bash
flutter build ipa --release --export-method app-store-connect
```

Output: `build/ios/ipa/*.ipa` (plus the archive under `build/ios/archive/`). If
export fails for signing reasons, open `build/ios/archive/Runner.xcarchive` in
Xcode → Organizer and distribute from there.

### 5.3 Upload

Easiest: **Transporter** (free, Mac App Store) → drag the `.ipa` → Deliver.

Or from Xcode Organizer → Distribute App → App Store Connect → Upload, which also
uploads the dSYMs for crash symbolication.

CI alternative, with an App Store Connect API key:

```bash
xcrun altool --upload-app -f build/ios/ipa/laffeh.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

Processing takes 5–30 minutes before the build appears in App Store Connect.

### 5.4 TestFlight first

- **Internal testing**: up to 100 people on your team, available as soon as the
  build processes, **no review**. Do this — it's the cheapest way to catch a
  signing or `.env` mistake before Apple sees it.
- **External testing**: needs a (fast, light) Beta App Review. Only worth it if
  you want testers outside the team.

Test on a **real device**, not just the simulator: GPS, the Share Extension, the
`laffeh://` deep links, and MapLibre's GPU path all behave differently there.

---

## 6. Store listing

### 6.1 Metadata (per language — ar / en / fr, matching the app)

| Field | Limit | Notes |
|---|---|---|
| Name | 30 | `Laffah` |
| Subtitle | 30 | e.g. "Plan smarter delivery routes" |
| Keywords | 100 total | comma-separated, no spaces, no repeating the name |
| Description | 4000 | what it does, who it's for |
| Promotional text | 170 | editable without a new build — useful |
| Support URL | required | a real page on afdal.tech that answers "how do I get help" |
| Marketing URL | optional | |
| Privacy Policy URL | required | `https://www.afdal.tech/policies/laffa-app.html#privacy-policy/en` |

- **Category**: Navigation (primary). Travel or Productivity as secondary.
- **Age rating**: answer the questionnaire honestly — 4+ is the expected outcome.
- **Copyright**: e.g. `2026 Afdal`.

### 6.2 Screenshots

Required: **iPhone 6.9"** (1290×2796 or 1320×2868 portrait). Apple scales these
down for smaller iPhones, so one set is enough. Add a 13" iPad set **only if** you
keep iPad support (§3.4).

Capture from the iOS Simulator (iPhone 16 Pro Max) with ⌘S, using the same shots
that worked for Play: the planner with stops, the optimized route summary, drive
mode, and the map picker. 3–5 images. No device frames with fake hardware, no
"coming soon" claims, and the content must be the real app.

No App Store equivalent of Play's feature graphic. The 1024×1024 icon is pulled
from the binary — nothing to upload separately.

---

## 7. App Review notes — write these carefully

Paste into *App Review Information → Notes*:

> Laffah plans optimized delivery routes for small fleets.
>
> **Demo account:** phone `<number>` / password `<password>` — already onboarded,
> so the reviewer can reach every screen.
>
> **Sign-in:** the app uses a phone number + password as the account credential
> (no SMS code is sent, so no real phone is needed to test). The phone number is
> the login identifier itself, not marketing data.
>
> **Without an account:** tapping "Skip for now" on the welcome screen gives full
> access for 7 days, so the app can also be evaluated without signing in.
>
> **Account deletion:** Settings → Delete account, with a confirmation listing
> exactly what is removed.
>
> **Location** is used only in the foreground, to show the driver on the map and
> to plan routes. Only the most recent fix is stored, overwritten each launch.
>
> **Adding a stop:** pick a point on the map, search an address, or paste a
> Google Maps link.

Also fill in a contact first/last name, phone and email that someone actually
monitors — Apple uses it when they have a question, and an unanswered question
becomes a rejection.

### Risk assessment — where this app could get rejected

| Risk | Guideline | Verdict / mitigation |
|---|---|---|
| Share-from-WhatsApp taught but absent on iOS | 2.1 App Completeness | ✅ Closed — the Share Extension ships, and the explainer states the iOS route through Maps (§2.4) |
| Missing purpose string for photo-library APIs | ITMS-90683 (automated) | ✅ Closed — `file_picker` dropped (§2.2) |
| Permission APIs compiled in but unused | ITMS-90683 | ✅ Closed — `permission_handler` dropped (§2.2) |
| iPad layout breakage | 2.1 / 4.0 Design | ✅ Closed — iPhone-only (§3.4) |
| Location purpose string only in Arabic | 5.1.1 | ✅ Closed — localized in ar/en/fr (§2.5) |
| Requiring a phone number to sign up | 5.1.1(ii) Data Minimization | Low — it's the credential, not extra data. Explained in the notes; the 7-day no-account path helps a lot |
| Reviewer can't reach features behind the trial wall | 2.1 | Give a real demo account; a fresh install has 7 days anyway |
| Login-required app with no clear value shown | 4.2 Minimum Functionality | Low — the app is substantial and works pre-login |

---

## 8. Submit

1. App Store Connect → your app → the version → attach the processed build.
2. Release option: **Manually release this version** for a first launch — you
   want to choose the moment it goes live, not discover it at 3 a.m.
3. Add for Review → Submit.

Review is typically **24–48 hours**. Rejections arrive in Resolution Center;
answer there in the same thread — a reply with a clear explanation resolves a
surprising share of them without a new build. If you disagree on the merits,
there's a formal appeal, but replying first is faster.

**After approval**: upload dSYMs if you didn't (Xcode does it automatically),
watch Crashes in Organizer, and remember every subsequent upload needs a bumped
build number.

---

## 9. Known gaps carried over from the Play release

1. **`.env` ships inside the IPA.** An `.ipa` is a zip — anyone can extract
   `Payload/Runner.app/Flutter/flutter_assets/.env`:
   - `SUPABASE_ANON_KEY` — fine, public by design, guarded by RLS.
   - `MAPBOX_ACCESS_TOKEN` — restrict it to this bundle id, or it can be billed
     against by anyone.
   - `AI_ROUTE_API_KEY` — **a real secret, currently extractable.** Move the call
     behind your own backend or issue scoped per-app keys. This is the one item
     here that is a genuine security problem rather than a store requirement.
2. **Stale golden tests.** 10 of 190 tests fail on pixel diffs — `splash`,
   `loader`, `fun_animations`, `marker_preview`, `trip_flow_preview`,
   `trip_overlay_repro`. Confirmed pre-existing: they fail identically with the
   iOS changes stashed. Refresh with `flutter test --update-goldens` once the
   current rendering is what you want. Nothing here blocks a submission.
3. **macOS / Windows / Linux** targets still carry `com.example.laffeh`. Not
   shipping, not urgent — but don't reuse those configs blindly later.
