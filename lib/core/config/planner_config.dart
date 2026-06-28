/// Tuning for point editing and local draft persistence.
class PlannerConfig {
  PlannerConfig._();

  // ── Tap-to-add guards ────────────────────────────────────
  /// Map widgets occasionally fire `onTap` twice in quick succession on
  /// some devices/emulators; an add arriving within this window of the
  /// previous one (and near it) is treated as a duplicate.
  static const Duration addPointDebounce = Duration(milliseconds: 350);

  /// A new point closer than this to an existing one is rejected.
  static const double minSeparationMeters = 8.0;

  /// The debounce dedup uses a looser radius than [minSeparationMeters]
  /// — this multiple of it — to swallow a jittered double-tap.
  static const double debounceDedupFactor = 6;

  // ── Draft persistence ────────────────────────────────────
  /// Rapid edits (typing a rename, dragging a marker) coalesce into a
  /// single disk write this long after the last change.
  static const Duration persistDebounce = Duration(milliseconds: 400);
}
