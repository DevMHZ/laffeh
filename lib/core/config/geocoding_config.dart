/// Tuning for place search — the box the driver types a destination into.
///
/// Every number here answers one question: *how much does "near me" count?*
/// A public geocoder ranks a query the way a librarian would — by how well
/// the text matches, across the whole planet. Ask the OSM search for
/// "صيدلية" and the first answer is a pharmacy in Istanbul, because a
/// librarian has no idea you are three streets from six of them. A driver
/// asking for a pharmacy is not asking the world; they are asking the next
/// ten minutes of their shift. The knobs below turn a librarian's answer
/// into a driver's answer.
class GeocodingConfig {
  GeocodingConfig._();

  // ── Typing ───────────────────────────────────────────────
  /// Wait after the last keystroke before the first (cheap, fast) provider
  /// is asked. Short enough to feel live, long enough that typing a word
  /// costs one request rather than one per letter.
  static const Duration debounce = Duration(milliseconds: 260);

  /// The slower, per-request-budgeted providers (Nominatim, Overpass) wait
  /// longer still — they are a *top-up* on what the fast one already showed,
  /// so they may lag a beat behind the list the driver is watching.
  static const Duration slowSourceDebounce = Duration(milliseconds: 650);

  /// One or two letters match half the country; below this the list is
  /// recents only.
  static const int minQueryLength = 2;

  // ── How far "near" reaches ───────────────────────────────
  /// The box the first pass is confined to. Wide enough to cover a city
  /// and its suburbs — the working day of almost every driver using this.
  static const double nearRadiusKm = 35;

  /// The second pass, run only when the first came back thin. Covers the
  /// governorate and its neighbours.
  static const double regionRadiusKm = 250;

  /// Below this many results the search widens a ring. A driver who typed a
  /// real address deserves the wider net; one who got ten good local hits
  /// does not need a request that can only add noise.
  static const int widenBelowResults = 5;

  /// Radius for a category sweep ("every pharmacy around here"). Kept tight:
  /// this returns *all* matches, not the best ones, so a wide radius is a
  /// long list of places the driver will never go to.
  static const double categoryRadiusKm = 8;

  /// Widened category sweep, when the tight one found almost nothing —
  /// rural rounds and small towns.
  static const double categoryWideRadiusKm = 25;

  // ── Ranking ──────────────────────────────────────────────
  /// Weights of the three things that make a result good. They sum to 1.
  static const double weightText = 0.38;
  static const double weightProximity = 0.47;
  static const double weightProminence = 0.15;

  /// Distance at which a result keeps ~37% of its proximity score, per kind
  /// of place. A shop 15 km away is a different shop; a *city* 400 km away
  /// is still the city you asked for by name, so administrative places
  /// decay far more slowly than pins do. Getting this wrong in either
  /// direction is a visible bug: too tight and "حلب" never appears from
  /// Damascus, too loose and the Istanbul pharmacy comes back.
  static const double decayKmPoi = 14;
  static const double decayKmAddress = 25;
  static const double decayKmStreet = 22;
  static const double decayKmArea = 90;
  static const double decayKmCity = 450;
  static const double decayKmRegion = 1200;

  /// How much of the proximity weight an *exact* name match may buy back.
  ///
  /// Distance-first is right until the driver names something precisely.
  /// "حلب" typed in Damascus is not a request for the sweet shop four
  /// hundred metres away that happens to have حلب in its name — it is a
  /// request for Aleppo, and no amount of proximity should outvote having
  /// said the name exactly. So an exact match relaxes the distance term
  /// rather than fighting it, and the weight it gives up moves to text.
  static const double exactMatchProximityRelief = 0.6;

  /// …but only for the kinds of place you name deliberately from far away.
  /// A *city* four hundred kilometres off is still the city you asked for;
  /// a *shop* four hundred kilometres off is somebody else's shop with the
  /// same name, and it must not climb back up the list on an exact match.
  static const double reliefShareRegion = 1.0;
  static const double reliefShareCity = 1.0;
  static const double reliefShareArea = 0.8;
  static const double reliefShareStreet = 0.35;
  static const double reliefShareAddress = 0.35;
  static const double reliefSharePoi = 0.30;

  // ── Merging ──────────────────────────────────────────────
  /// Two hits this close together, with the same name, are one place seen
  /// by two providers. The survivor is whichever carries more address
  /// context, so the tile can say *which* branch it is.
  static const double dedupeMeters = 90;

  /// How many results reach the list. More than this and the driver is
  /// scrolling a directory instead of picking a stop.
  static const int maxResults = 12;

  /// Per-provider ask. Deliberately larger than [maxResults] — over-fetching
  /// is what gives the local ranker something to actually choose between.
  static const int providerLimit = 25;

  // ── Cache ────────────────────────────────────────────────
  /// Repeat queries inside a session (backspace, retype, reopen the sheet)
  /// answer from memory. Keyed on the query *and* a coarse location, since
  /// the same word means a different list once the driver has moved on.
  static const int cacheEntries = 80;
  static const Duration cacheTtl = Duration(minutes: 12);

  /// Location is rounded to this many decimal places for the cache key —
  /// ~1 km, so ordinary driving does not thrash the cache but a real move
  /// to another town does.
  static const int cacheLocationPrecision = 2;

  // ── Recents ──────────────────────────────────────────────
  /// Places the driver actually chose, offered before they type a letter
  /// and merged in as they do. The single highest-signal source there is:
  /// a delivery round is the same twenty addresses most weeks.
  static const int maxRecents = 40;

  /// How many recents show on the empty sheet.
  static const int recentsOnEmptyQuery = 6;

  // ── Timeouts ─────────────────────────────────────────────
  /// A search that has not answered by now is not part of this keystroke.
  /// Well under the app-wide network timeout: the driver is typing, and a
  /// provider that stalls must not hold the whole list hostage.
  static const Duration providerTimeout = Duration(seconds: 6);

  /// Overpass runs a real query over a real database; it is allowed longer,
  /// and its results land after the text list is already on screen.
  static const Duration categoryTimeout = Duration(seconds: 12);
}
