# Named Google Maps place sharing — 1.0.6

## Diagnosis

The customer's screenshot shows a completed iOS share handoff followed by the
“No addresses found” message. It does not include the failing URL, so the exact
customer place has not been replayed. Code inspection and live requests exposed
three reproducible failure paths:

- `receive_sharing_intent` 1.8.1 persisted attachments when the last array index
  completed, even if an earlier URL was still loading. It also selected text
  before URL representations and read only the first extension item.
- A named place can use a Place ID, CID, or feature ID instead of coordinates.
  Google sometimes returns an HTML shell whose declared place-detail preload
  contains the actual pin. The old resolver stopped at that shell.
- For identifier-only links in the EU, unwrapping `consent.google.com` returned
  to the same visited Maps URL and stopped. Following Google's ordinary GET
  redirect resolves the place without submitting a consent form.

Google's documented Maps URL precedence is described in
[Maps URLs: Search parameters](https://developers.google.com/maps/documentation/urls/get-started#search-action).

## Changes

The app-local iOS share controller waits for every URL/text provider across all
extension items, prefers URL with a text fallback, preserves order, and removes
exact duplicates. It retains the existing App Group encoding and app handoff.
Dependency sources and package versions are unchanged.

The resolver follows Maps navigation metadata and a same-origin HTTPS
`/maps/preview/place` preload. It validates the requested identity against the
returned place record before accepting its coordinates and name. The requested
identity survives redirects. Camera coordinates, static images, unrelated
records, invalid coordinates and foreign preview origins are rejected.

The preload format is an undocumented Google web response. Its small parser is
isolated and fails closed if the format changes. Existing direct coordinate
shares still work without a network request. ID-only and shortened links require
internet access. Sharing failures now show a place-specific, localized message
in Arabic, English and French, including an offline recovery instruction.

## Validation — 2026-09-21

- 447 route-planner/navigation tests pass, including 16 new resolver regressions.
- 7 native Swift collector tests pass, including a slower URL completing after
  the final text attachment, concurrent callbacks, URL preference and fallback.
- Live Dart/Dio requests resolve a Sydney Opera House Place ID, Coral CID, and
  the existing Coral short link. The Place ID result is approximately
  `-33.8567844,151.2152967`; no viewport coordinate is substituted.
- The older Coral short-link fixture contains historical pin coordinates. It
  remains a URL parsing regression, not a claim about the live business record.
- Changed Dart files analyze cleanly; `git diff --check` passes.
- Runner and its Share Extension build and launch successfully on the selected
  iPhone 17 Pro Simulator through ordinary `flutter run`. The project, extension
  and Pod targets now require iOS 15.0, compatible with Xcode 27. `pod install`
  preserves this minimum and the complete lockfile, with no temporary build
  overrides. See [native build verification](navigation-fixes-1.0.6.md).

Run native tests from the repository root:

```sh
swiftc -swift-version 5 -D SHARE_PAYLOAD_TEST \
  'ios/Share Extension/ShareViewController.swift' \
  test/native/share_payload_collector_test.swift -o /tmp/laffeh-share-tests
/tmp/laffeh-share-tests
```

The customer must install a build containing this change to exercise the new
extension. The precise customer link and a physical Google Maps-to-Laffeh share
remain device acceptance checks. No store upload or Git push was performed.
