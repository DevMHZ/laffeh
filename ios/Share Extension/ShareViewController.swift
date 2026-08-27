import receive_sharing_intent

/// The iOS half of the location import.
///
/// Anything the user shares as text or a link — a Maps URL out of Apple Maps
/// or Google Maps, a link pasted into a chat — arrives here, gets written to
/// the shared App Group, and the host app is reopened to read it. All of that
/// lives in `RSIShareViewController`; this subclass exists only so the
/// extension has a principal class of its own, and so `shouldAutoRedirect`
/// stays at its default (`true`): the user picked Laffah from the share
/// sheet, so there is nothing left to confirm.
///
/// The Dart side consumes it in `ShareIntentHandler`.
class ShareViewController: RSIShareViewController {}
