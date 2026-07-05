import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'vehicle_kind.dart';

/// Decodes and caches the pre-rendered 3D vehicle sprites for canvas
/// drawing (the native map symbols). Widget surfaces use `Image.asset`
/// directly and never need this.
class VehicleSprites {
  VehicleSprites._();

  static final Map<String, ui.Image> _cache = {};

  /// The decoded sprite for [kind], or null for painter-drawn vehicles.
  static Future<ui.Image?> of(VehicleKind kind) => _load(kind.spriteAsset);

  /// The decoded turntable sheet for [kind] (72 frames, 9×8 grid), or
  /// null for painter-drawn vehicles.
  static Future<ui.Image?> turntableOf(VehicleKind kind) =>
      _load(kind.turntableAsset);

  /// The decoded nav sheet for [kind] (48 headings × 4 phases — see
  /// [VehicleNavSheet]), or null for painter-drawn vehicles and when the
  /// baked asset is missing (callers then fall back to the flat sprite).
  ///
  /// Nav sheets are ~20 MB decoded, so loading one evicts every other
  /// kind's sheet — only the selected vehicle stays resident. Evicted
  /// images are not disposed here (a painter may still be drawing one
  /// mid-switch); dropping the cache reference lets the GC reclaim them.
  static Future<ui.Image?> navOf(VehicleKind kind) async {
    final asset = kind.navAsset;
    if (asset == null) return null;
    for (final other in VehicleKind.values) {
      final otherAsset = other.navAsset;
      if (otherAsset != null && otherAsset != asset) {
        _cache.remove(otherAsset);
      }
    }
    try {
      return await _load(asset);
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _load(String? asset) async {
    if (asset == null) return null;
    final cached = _cache[asset];
    if (cached != null) return cached;
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    return _cache[asset] = image;
  }
}
