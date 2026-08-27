/// Tuning for the offline map cache — how much may be stored, the shape of
/// the two kinds of pack we download, and how politely we hit the tile host.
///
/// Two separate mechanisms live behind these numbers:
///   * the **ambient cache**, which MapLibre fills on its own from ordinary
///     panning and evicts LRU-style once the native size cap is reached
///     (the plugin exposes no setter for it, so it is free but not
///     something we can rely on); and
///   * **offline packs**, explicitly downloaded and never evicted until
///     deleted. There are two kinds: an *area* around the driver, which
///     needs no route at all, and a route *corridor*.
class OfflineMapConfig {
  OfflineMapConfig._();

  // ── Storage ceiling ──────────────────────────────────────
  /// Ceiling on tiles held across every downloaded pack.
  ///
  /// Despite the plugin's generic name, `setOfflineTileCountLimit` maps to
  /// the native `setOfflineMapboxTileCountLimit` / `setMaximumAllowedMapboxTiles`
  /// — it bounds *downloaded regions*, not the ambient cache. The native
  /// default is 6000 tiles, which a single 30 km area pack plus a couple of
  /// corridors would run straight into; downloads then stop silently
  /// mid-region. Raising it is what makes route-independent offline maps
  /// possible at all.
  ///
  /// Vector tiles average well under 100 KB, so this is a soft ceiling of
  /// roughly a few hundred MB in the worst case and far less in practice.
  static const int offlineRegionTileLimit = 60000;

  // ── Politeness to the tile host ──────────────────────────
  /// A download that opens dozens of sockets at once gets rate-limited by
  /// the CDN in front of the tile server, which surfaces as a half-finished
  /// region. Capping concurrency trades a slower download for one that
  /// actually completes.
  static const int maxConcurrentRequests = 6;
  static const int maxRequestsPerHost = 4;

  // ── Size estimates ───────────────────────────────────────
  /// Average payload of one vector tile across the zoom span we download,
  /// used only to warn the user before starting. Measured against
  /// OpenFreeMap's `liberty` style; real payloads vary a lot with how
  /// built-up the area is, which is why every figure built on it is shown
  /// as an approximation.
  static const double estimatedKbPerTile = 45;

  // ── Area packs (no route needed) ─────────────────────────
  /// Prefix every saved area's pack id carries, so areas can be told apart
  /// from route corridors when the stored regions are enumerated.
  ///
  /// One id *per saved area*, not one id for all of them. A single shared id
  /// was the earlier design and it was wrong the moment the driver could
  /// choose where to save: downloading a second city silently deleted the
  /// first, and the button offered to "update" a map that was nowhere near
  /// what the driver had framed.
  static const String areaPackPrefix = 'area.';

  /// Ceiling on how many areas may be kept at once. Not a storage limit —
  /// [offlineRegionTileLimit] is that — but a guard against a list nobody
  /// can reason about, and against tiles piling up unnoticed.
  static const int maxAreaPacks = 12;

  /// How close two areas must be to count as the same one, as a fraction of
  /// the smaller area's span.
  ///
  /// This is what decides whether the button says "download" or "update", so
  /// it wants to be forgiving: a driver re-framing the city they saved last
  /// week will never reproduce the same rectangle by thumb, and telling them
  /// they are about to download a second copy of it would be worse than
  /// treating a near-miss as a refresh.
  static const double areaSameCentreFraction = 0.35;

  /// How far the picker's frame reaches from the driver when it opens, as a
  /// *half-edge* — 15 km frames a 30 × 30 km map.
  ///
  /// Only an opening shot, not a limit: the driver pans and zooms from here
  /// to whatever they actually want. A city's worth of map is the right
  /// thing to find already framed, because the common case is "save where I
  /// am" and that case should cost no gestures at all.
  static const double defaultAreaRadiusKm = 15;

  /// Ceiling on one area download.
  ///
  /// The picker lets the driver frame anything, including a whole country
  /// at low zoom, so a ceiling has to live somewhere. It is expressed in
  /// megabytes rather than kilometres because megabytes are what the driver
  /// is actually spending — and because the same rectangle costs wildly
  /// different amounts over a city and over a desert.
  ///
  /// 250 MB is roughly a 150 × 150 km box: far more than a day's driving,
  /// comfortably inside [offlineRegionTileLimit], and small enough that a
  /// mis-framed selection can't quietly eat a phone's storage.
  static const double maxAreaMb = 250;

  /// Edge of one downloaded cell of the area grid.
  ///
  /// One box for the whole area is the obvious approach and the wrong one:
  /// a single 60 × 60 km region is one all-or-nothing download that reports
  /// no useful progress and dies whole on a timeout. Cells give granular
  /// progress and let a failed corner be retried without refetching the
  /// rest.
  static const double areaCellKm = 12;

  /// Overlap added around each cell, so the seams between them never show
  /// as a missing sliver of map.
  static const double areaSeamPaddingKm = 0.4;

  /// Zoom span downloaded for an area — the same reasoning as the corridor
  /// below, one level shallower at the bottom since an area pack is
  /// already anchored where the driver is.
  static const double areaMinZoom = 8;
  static const double areaMaxZoom = 14;

  /// Hard ceiling on cells, so a mis-typed radius can't queue a download
  /// that never ends. 30 km at a 12 km cell is 36 cells, well under this.
  static const int maxAreaCells = 100;

  // ── Route corridor ───────────────────────────────────────
  /// Road length covered by each downloaded box.
  ///
  /// One box around the whole route is the obvious approach and the wrong
  /// one: a trip between two cities would download the entire rectangle
  /// between them, nearly all of which is off-route. Chunking along the
  /// path keeps the download proportional to the road actually driven.
  static const double corridorChunkKm = 8;

  /// Margin added around each box, so a driver who drifts a block off-route
  /// still has map under them.
  static const double corridorPaddingKm = 1.5;

  /// Zoom span downloaded per box.
  ///
  /// Stopping at 14 rather than 17 is deliberate: these are *vector* tiles,
  /// and MapLibre overzooms them — a z18 view renders fine from z14 data,
  /// losing only some label density. Each extra zoom level quadruples the
  /// tile count, so 14 costs roughly a sixteenth of what 16 would while
  /// staying legible at driving speed.
  static const double corridorMinZoom = 6;
  static const double corridorMaxZoom = 14;

  /// Upper bound on boxes per route. A very long trip stretches its chunks
  /// instead of downloading hundreds of regions.
  static const int maxCorridorChunks = 40;

  /// Pack id the working plan's corridor is always stored under.
  ///
  /// One stable id, so re-optimizing replaces the stored map instead of
  /// stacking copies of it — and so a screen that has no route in hand
  /// (Settings) can still say what is saved for the trip and delete it.
  static const String tripPackId = 'planner.current';

  // ── Region metadata keys ─────────────────────────────────
  /// Regions are tagged so a pack's boxes can be found and deleted as a
  /// unit, instead of accumulating forever.
  static const String metaPackId = 'laffeh.packId';
  static const String metaKind = 'laffeh.kind';

  /// The whole pack's rectangle, as `south,west,north,east`, written onto
  /// every box.
  ///
  /// Stored natively beside the tiles rather than in preferences so there is
  /// one source of truth: a saved area that no longer has regions behind it
  /// cannot linger in a list, and a list cannot go missing while its tiles
  /// still occupy the disk.
  static const String metaBounds = 'laffeh.bounds';

  static const String kindCorridor = 'corridor';
  static const String kindArea = 'area';
}
