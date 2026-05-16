import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// Generates [BitmapDescriptor]s on the fly so we don't ship asset
/// PNGs for every marker style we need. Cheap canvas-rendered icons
/// that match the brand palette and stay crisp on hi-DPI screens.
class MarkerFactory {
  MarkerFactory._();

  static Future<BitmapDescriptor> _drawCircleMarker({
    required Color fill,
    required Color border,
    required IconData icon,
    Color iconColor = Colors.white,
    double size = 96,
    double iconScale = 0.55,
    bool dropShadow = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 4;

    // Shadow (optional)
    if (dropShadow) {
      canvas.drawCircle(
        center.translate(0, 3),
        radius,
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Fill
    canvas.drawCircle(center, radius, Paint()..color = fill);

    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = border,
    );

    // Icon
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * iconScale,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    final img = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size / 2,
    );
  }

  /// Cache to avoid re-rasterising on every state emission.
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> _cached(
    String key,
    Future<BitmapDescriptor> Function() build,
  ) async {
    final existing = _cache[key];
    if (existing != null) return existing;
    final built = await build();
    _cache[key] = built;
    return built;
  }

  static Future<BitmapDescriptor> depot() => _cached(
        'depot',
        () => _drawCircleMarker(
          fill: AppColors.primary,
          border: AppColors.white,
          icon: Icons.flag_rounded,
        ),
      );

  static Future<BitmapDescriptor> stop(int index) => _cached(
        'stop_$index',
        () async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const size = 96.0;
          final center = const Offset(size / 2, size / 2);
          final radius = size / 2 - 4;

          canvas.drawCircle(
            center.translate(0, 3),
            radius,
            Paint()
              ..color = Colors.black.withOpacity(0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          canvas.drawCircle(center, radius, Paint()..color = AppColors.accent);
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = AppColors.white,
          );

          final tp = TextPainter(textDirection: TextDirection.ltr)
            ..text = TextSpan(
              text: '$index',
              style: const TextStyle(
                fontFamily: 'Almarai',
                fontWeight: FontWeight.w800,
                fontSize: 40,
                color: Colors.white,
              ),
            )
            ..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

          final img = await recorder.endRecording().toImage(
                size.toInt(),
                size.toInt(),
              );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          return BitmapDescriptor.bytes(
            bytes!.buffer.asUint8List(),
            width: size / 2,
          );
        },
      );

  /// Bigger, rotation-friendly marker used for the simulation vehicle.
  /// We don't cache by rotation — rotation is applied at the [Marker]
  /// level via `rotation:` so a single bitmap is reused for all frames.
  static Future<BitmapDescriptor> vehicle() => _cached(
        'vehicle',
        () async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const size = 110.0;
          final center = const Offset(size / 2, size / 2);

          // outer halo
          canvas.drawCircle(
            center,
            size / 2 - 4,
            Paint()..color = AppColors.accent.withOpacity(0.20),
          );
          // inner pill
          canvas.drawCircle(
            center,
            size / 2 - 22,
            Paint()..color = AppColors.accent,
          );
          canvas.drawCircle(
            center,
            size / 2 - 22,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = AppColors.white,
          );

          // car icon
          final tp = TextPainter(textDirection: TextDirection.ltr)
            ..text = TextSpan(
              text: String.fromCharCode(Icons.local_shipping_rounded.codePoint),
              style: TextStyle(
                fontSize: 38,
                fontFamily: Icons.local_shipping_rounded.fontFamily,
                package: Icons.local_shipping_rounded.fontPackage,
                color: Colors.white,
              ),
            )
            ..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

          final img = await recorder.endRecording().toImage(
                size.toInt(),
                size.toInt(),
              );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          return BitmapDescriptor.bytes(
            bytes!.buffer.asUint8List(),
            width: 56,
          );
        },
      );
}
