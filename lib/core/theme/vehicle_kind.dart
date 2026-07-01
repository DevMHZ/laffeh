import 'package:flutter/material.dart';

import '../utils/marker_factory.dart';

/// Selectable playback/drive vehicle marker — the top-down icon that
/// represents the driver on the map during simulation and live navigation.
enum VehicleKind {
  vwBus('vwBus'),
  vespa('vespa');

  /// Stable id used for persistence + Settings selection.
  final String id;

  const VehicleKind(this.id);

  static VehicleKind byId(String id) =>
      values.firstWhere((v) => v.id == id, orElse: () => vwBus);

  /// A fresh top-down painter for this vehicle, drawn pointing "up" (north)
  /// — callers rotate it to the travel bearing.
  CustomPainter painter() => switch (this) {
    VehicleKind.vwBus => const TopViewVwBusPainter(),
    VehicleKind.vespa => const TopViewVespaPainter(),
  };
}
