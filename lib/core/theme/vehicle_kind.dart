import 'package:flutter/material.dart';

import '../utils/marker_factory.dart';

/// Selectable playback/drive vehicle avatar — represents the driver on the
/// map during simulation and live navigation. Four options are 3D models
/// pre-rendered to top-down sprites (front pointing up); [arrow] is the
/// classic minimal navigation dart, drawn in code.
enum VehicleKind {
  vwBus('vwBus', 'assets/vehicles/vw_bus.png'),
  taxi('taxi', 'assets/vehicles/mercedes_taxi.png'),
  vespa('vespa', 'assets/vehicles/vespa_rider.png'),
  camel('camel', 'assets/vehicles/desert_camel.png'),
  arrow('arrow', null);

  /// Stable id used for persistence + Settings selection.
  final String id;

  /// Pre-rendered sprite (transparent PNG, front pointing up), or null
  /// when the vehicle is drawn by [painter].
  final String? spriteAsset;

  const VehicleKind(this.id, this.spriteAsset);

  /// 72-frame turntable sprite sheet (9×8 grid, 5° per frame, garage
  /// three-quarter camera) used by the Settings picker's spinning
  /// showcase. Null for painter-drawn vehicles.
  String? get turntableAsset =>
      spriteAsset?.replaceFirst('.png', '_turn.png');

  /// Nav sprite sheet for the map marker (48 headings × 4 animation
  /// phases, 55° map camera — see `VehicleNavSheet`). Null for
  /// painter-drawn vehicles.
  String? get navAsset => spriteAsset?.replaceFirst('.png', '_nav.png');

  static VehicleKind byId(String id) =>
      values.firstWhere((v) => v.id == id, orElse: () => vwBus);

  /// Painter for code-drawn vehicles (only [arrow]); null for sprites.
  CustomPainter? painter() =>
      this == VehicleKind.arrow ? const TopViewArrowPainter() : null;

  /// The avatar pointing "up" (north at bearing 0) in a [size] square —
  /// callers rotate it to the travel bearing.
  Widget avatar({required double size}) {
    final asset = spriteAsset;
    if (asset == null) {
      return CustomPaint(size: Size.square(size), painter: painter());
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
