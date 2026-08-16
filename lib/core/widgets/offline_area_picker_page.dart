import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uuid/uuid.dart';

import '../config/env_config.dart';
import '../config/map_config.dart';
import '../config/offline_map_config.dart';
import '../constants/app_constants.dart';
import '../network/network_info.dart';
import '../services/map_cache_service.dart';
import '../services/map_pack_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/area_grid.dart';
import '../utils/debug_log.dart';
import '../utils/distance_utils.dart';
import '../utils/location_utils.dart';
import '../utils/tile_math.dart';
import 'app_dialog.dart';
import 'map_pack_progress_view.dart';

part 'offline_area_picker_widgets.dart';

/// Opens the offline-map picker: frame an area on the map, see what it
/// costs, download it.
///
/// Reached from two places — the offer on the planning sheet and the row in
/// Settings — so there is exactly one description of what a download costs
/// and one place a running download is watched.
///
/// The download deliberately outlives the page. [MapPackController.area]
/// lives outside the widget tree, so leaving mid-download leaves it running
/// and coming back finds the progress where it actually is.
Future<void> openOfflineAreaPicker(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const OfflineAreaPickerPage()),
  );
}

/// "Save this piece of map" — the driver frames it themselves.
///
/// The earlier version of this screen offered three radii around the
/// driver's own position, which quietly assumed the map someone needs is
/// the map they are standing in. It usually isn't: a driver plans tomorrow's
/// run from home for a district across town, or leaves for a city they have
/// not reached yet. Framing the area on a map answers both, and still costs
/// nothing extra for the common case — the frame opens around the driver,
/// so "save where I am" is one button and no gestures.
///
/// The map is a sibling of the summary card rather than sitting behind it.
/// A full-bleed map with a card floating over the bottom looks better and is
/// *wrong here*: the frame has to mean exactly what downloads, and a card
/// whose height changes between the button and the progress bar would move
/// the frame's bottom edge under the driver mid-download.
class OfflineAreaPickerPage extends StatefulWidget {
  const OfflineAreaPickerPage({super.key});

  @override
  State<OfflineAreaPickerPage> createState() => _OfflineAreaPickerPageState();
}

class _OfflineAreaPickerPageState extends State<OfflineAreaPickerPage> {
  final MapPackController _pack = MapPackController.area;

  MapLibreMapController? _controller;

  /// Size of the map's own box, and the frame's rectangle within it, both
  /// settled during layout and read back when the camera next reports.
  /// Kept as one pair so the rectangle that is *painted* and the rectangle
  /// that is *priced* can never drift apart.
  Size? _mapSize;
  Rect? _frameOnScreen;

  /// What the frame currently encloses. Null until the map reports its
  /// first camera position.
  CoordinateBounds? _selection;

  /// The size quoted when download was pressed, so the denominator under
  /// the progress bar stays the number the driver agreed to.
  double? _quotedMb;

  /// True while a fix is being fetched for the recentre button.
  bool _locating = false;

  /// Areas already saved on this device, drawn on the map so the driver can
  /// see what they have before spending data on it again.
  List<SavedMapArea> _saved = const [];

  /// The saved area the frame is currently sitting on, if any. This is what
  /// separates "download" from "update": without it the button could only
  /// ask whether *something* was stored, and would offer to update a map of
  /// another city entirely.
  SavedMapArea? get _matched {
    final selection = _selection;
    if (selection == null) return null;
    for (final area in _saved) {
      if (AreaGrid.isSameArea(selection, area.bounds)) return area;
    }
    return null;
  }

  /// Where the frame sits inside the map box. The margins keep the
  /// surrounding context visible — you cannot judge whether a frame covers
  /// your city without seeing a little of what falls outside it.
  static const double _frameInsetX = 22;
  static const double _frameInsetBottom = 26;

  /// Clearance below the floating header, measured from under the status
  /// bar. The header must never overlap the frame: a frame with its top
  /// edge hidden behind a card is a frame whose contents the driver cannot
  /// actually see.
  static const double _headerClearance = 88;

  @override
  void initState() {
    super.initState();
    _reloadSaved();
  }

  /// Re-reads what is stored and redraws it on the map.
  Future<void> _reloadSaved() async {
    final saved = await MapCacheService.savedAreas();
    if (!mounted) return;
    setState(() => _saved = saved);
    await _drawSaved();
  }

  /// Paints the saved areas as native fills rather than into the overlay
  /// canvas, so they travel with the map under a pan instead of lagging a
  /// frame behind it.
  Future<void> _drawSaved() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.clearFills();
      for (final area in _saved) {
        final sw = area.bounds.southWest;
        final ne = area.bounds.northEast;
        await controller.addFill(
          FillOptions(
            geometry: [
              [
                LatLng(sw.latitude, sw.longitude),
                LatLng(sw.latitude, ne.longitude),
                LatLng(ne.latitude, ne.longitude),
                LatLng(ne.latitude, sw.longitude),
                LatLng(sw.latitude, sw.longitude),
              ],
            ],
            fillColor: _hex(AppColors.success),
            fillOutlineColor: _hex(AppColors.success),
            fillOpacity: 0.18,
          ),
        );
      }
    } catch (e) {
      // Fills are an aid, not the feature — a platform that refuses them
      // still prices and downloads correctly.
      DebugLog.map('area picker: drawing saved areas failed — $e');
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  // ── Map ────────────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    await _drawSaved();

    // Frame the driver's own surroundings to open on, falling back to the
    // map's default city when there is no fix yet — which is the ordinary
    // case on a fresh install, before anything has asked for a position.
    //
    // Framing *something* matters more than framing the right place: the
    // opening shot has to be a sensible amount of ground, and leaving the
    // camera at its initial zoom put a 4 km sliver in a frame meant to hold
    // a city. The driver can pan; they should not have to zoom out first.
    final here = await LocationUtils.getLastKnownLatLng();
    if (!mounted) return;
    await _frameAround(
      here ?? const ll.LatLng(MapConfig.fallbackLat, MapConfig.fallbackLon),
    );
  }

  /// Fits the frame around [center] at the default reach.
  ///
  /// The camera padding is taken from the frame's own rectangle rather than
  /// from the inset constants, so the square lands *in the frame* instead of
  /// merely on screen — the two would drift apart the moment a device with a
  /// different status bar changed where the frame sits.
  Future<void> _frameAround(ll.LatLng center) async {
    final controller = _controller;
    final frame = _frameOnScreen;
    final size = _mapSize;
    if (controller == null || frame == null || size == null) return;

    final square = AreaGrid.squareAround(
      center,
      radiusKm: OfflineMapConfig.defaultAreaRadiusKm,
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              square.southWest.latitude,
              square.southWest.longitude,
            ),
            northeast: LatLng(
              square.northEast.latitude,
              square.northEast.longitude,
            ),
          ),
          left: frame.left,
          right: size.width - frame.right,
          top: frame.top,
          bottom: size.height - frame.bottom,
        ),
      );
    } catch (e) {
      DebugLog.map('area picker: framing failed — $e');
    }
    await _refreshSelection();
  }

  /// Re-reads what the frame encloses.
  ///
  /// Driven by camera *idle* rather than camera move: every call is a
  /// platform round-trip, and a figure that settles the moment the driver
  /// lifts their finger is worth more than one that flickers under it.
  Future<void> _refreshSelection() async {
    final controller = _controller;
    final size = _mapSize;
    final frame = _frameOnScreen;
    if (controller == null || size == null || size.isEmpty || frame == null) {
      return;
    }
    // A running download is fetching the rectangle that was framed when the
    // button was pressed. The driver can still pan the map underneath it —
    // but re-pricing the card to wherever they wandered would describe a
    // download that isn't the one happening.
    if (_pack.isBusy) return;

    try {
      final visible = await controller.getVisibleRegion();
      if (!mounted) return;
      final selection = _frameBounds(visible, size, frame);
      if (selection == null) return;
      setState(() => _selection = selection);
    } catch (e) {
      // No platform behind the map (tests, an unsupported device) — the
      // page still renders, it just cannot price anything.
      DebugLog.map('area picker: visible region unavailable — $e');
    }
  }

  /// The frame's screen rectangle inside a map box of [size], on a device
  /// whose status bar is [safeTop] tall.
  static Rect _frameRect(Size size, double safeTop) => Rect.fromLTRB(
    _frameInsetX,
    safeTop + _headerClearance,
    size.width - _frameInsetX,
    size.height - _frameInsetBottom,
  );

  /// Turns the frame's screen rectangle back into coordinates.
  ///
  /// Longitude is linear across the viewport, latitude is not — Mercator
  /// stretches it towards the poles — so the vertical edges are
  /// interpolated in projected space via [TileMath]. Doing it this way
  /// rather than through the map's own `toLatLng` also sidesteps the
  /// projection's platform split, where Android answers in physical pixels
  /// and iOS in logical ones.
  ///
  /// Exact only for a north-up, untilted map, which is why this screen
  /// disables both gestures.
  CoordinateBounds? _frameBounds(LatLngBounds visible, Size size, Rect frame) {
    if (frame.width <= 0 || frame.height <= 0) return null;

    final west = visible.southwest.longitude;
    final lonSpan = visible.northeast.longitude - west;
    // Negative across the antimeridian; nothing sane to download there, so
    // the last good selection stands rather than a rectangle spanning the
    // globe the wrong way.
    if (lonSpan <= 0) return null;

    final yNorth = TileMath.normalizedY(visible.northeast.latitude);
    final ySouth = TileMath.normalizedY(visible.southwest.latitude);
    final ySpan = ySouth - yNorth;
    if (ySpan <= 0) return null;

    double lonAt(double x) => west + lonSpan * (x / size.width);
    double latAt(double y) =>
        TileMath.latAtNormalizedY(yNorth + ySpan * (y / size.height));

    return CoordinateBounds(
      southWest: ll.LatLng(latAt(frame.bottom), lonAt(frame.left)),
      northEast: ll.LatLng(latAt(frame.top), lonAt(frame.right)),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _recentre() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _locating = true);
    ll.LatLng? here;
    try {
      here = await LocationUtils.getCurrentLatLng();
    } catch (_) {
      here = await LocationUtils.getLastKnownLatLng();
    } finally {
      if (mounted) setState(() => _locating = false);
    }

    if (!mounted) return;
    if (here == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.offlineAreaNeedsLocation)),
      );
      return;
    }
    await _frameAround(here);
  }

  Future<void> _download(
    CoordinateBounds selection,
    List<CoordinateBounds> boxes,
    double estimateMb,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!await NetworkInfo().isConnected) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.offlineMapNeedsConnection)),
      );
      return;
    }
    if (!mounted || boxes.isEmpty) return;

    // Re-framing a saved area downloads over *that* pack; anywhere else
    // gets an id of its own. This is the whole difference between updating
    // a map and silently replacing one.
    final packId =
        _matched?.packId ??
        '${OfflineMapConfig.areaPackPrefix}${const Uuid().v4()}';

    setState(() => _quotedMb = estimateMb);
    await _pack.download(
      packId: packId,
      boxes: boxes,
      packBounds: selection,
    );
    if (!mounted) return;
    await _reloadSaved();
  }

  Future<void> _confirmDelete(SavedMapArea area) async {
    final size = AreaGrid.sizeKm(area.bounds);
    final ok = await AppDialog.confirm(
      context: context,
      title: AppStrings.offlineAreaDeleteTitle,
      message: AppStrings.offlineAreaDeleteMessageOf(
        AppStrings.offlineAreaDimensions(size.widthKm, size.heightKm),
        AppStrings.megabytes(area.storedMb),
      ),
      confirmLabel: AppStrings.offlineMapDelete,
      confirmIcon: Iconsax.trash,
      destructive: true,
    );
    if (ok != true) return;

    await MapCacheService.deletePack(area.packId);
    if (!mounted) return;
    _pack.reset();
    await _reloadSaved();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final boxes = selection == null
        ? const <CoordinateBounds>[]
        : AreaGrid.cover(selection);
    final estimateMb = TileMath.estimatedMb(
      boxes,
      minZoom: OfflineMapConfig.areaMinZoom,
      maxZoom: OfflineMapConfig.areaMaxZoom,
    );
    final size = selection == null ? null : AreaGrid.sizeKm(selection);
    final tooLarge = estimateMb > OfflineMapConfig.maxAreaMb;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final box = constraints.biggest;
                // Settled during layout, used by the next selection refresh
                // — never written back into state from here.
                _mapSize = box;
                final frame = _frameRect(
                  box,
                  MediaQuery.paddingOf(context).top,
                );
                _frameOnScreen = frame;
                return Stack(
                  children: [
                    Positioned.fill(child: _map(box)),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _FramePainter(
                            frame: frame,
                            border: AppColors.primary,
                            scrim: AppColors.asphaltDark.withValues(
                              alpha: 0.32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _header(),
                    _recentreButton(),
                  ],
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: _pack,
            builder: (context, _) {
              final matched = _matched;
              // A driver at the ceiling can still refresh what they have —
              // only a *new* area is refused, which is the one that would
              // add to the pile.
              final atCeiling =
                  matched == null &&
                  _saved.length >= OfflineMapConfig.maxAreaPacks;

              return OfflineAreaPickerCard(
                pack: _pack,
                widthKm: size?.widthKm,
                heightKm: size?.heightKm,
                estimateMb: estimateMb,
                quotedMb: _quotedMb ?? estimateMb,
                tooLarge: tooLarge,
                atCeiling: atCeiling,
                savedHere: matched,
                savedCount: _saved.length,
                statusApplies:
                    _pack.packId != null && _pack.packId == matched?.packId,
                onDownload: selection == null || tooLarge || atCeiling
                    ? null
                    : () => _download(selection, boxes, estimateMb),
                onDelete: matched == null
                    ? null
                    : () => _confirmDelete(matched),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _map(Size box) {
    return MapLibreMap(
      styleString: EnvConfig.mapStyleUrl,
      initialCameraPosition: const CameraPosition(
        target: LatLng(MapConfig.fallbackLat, MapConfig.fallbackLon),
        zoom: MapConfig.initialZoom,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _refreshSelection,
      trackCameraPosition: true,
      compassEnabled: false,
      // Push the OpenStreetMap "i" attribution button off-screen so the
      // corner stays clean (negative margins move it past the edge).
      attributionButtonMargins: const math.Point(-100, -100),
      // Both gestures are off because the frame's coordinates are derived
      // assuming a north-up, flat map — allowing either would make the
      // rectangle quietly stop matching what downloads.
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      myLocationEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapConfig.minZoom,
        MapConfig.maxZoom,
      ),
    );
  }

  Widget _header() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _MapChipButton(
                icon: Icons.arrow_back_rounded,
                tooltip: AppStrings.close,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadowSoft, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.offlineAreaPickTitle,
                        style: AppTextStyles.titleSm,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.offlineAreaPickHint,
                        style: AppTextStyles.mutedSm,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentreButton() {
    return Positioned(
      // Sits inside the frame rather than over its edge: a control laid
      // across the corner ticks reads as part of the frame, and invites a
      // drag that does nothing.
      right: _frameInsetX + 12,
      bottom: _frameInsetBottom + 16,
      child: _MapChipButton(
        icon: Iconsax.gps,
        tooltip: AppStrings.offlineAreaMyLocation,
        busy: _locating,
        onTap: _locating ? null : _recentre,
      ),
    );
  }
}
