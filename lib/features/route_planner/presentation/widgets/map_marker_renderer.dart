import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/config/vehicle_marker_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/vehicle_kind.dart';
import '../../../../core/theme/vehicle_nav_sheet.dart';
import '../../../../core/theme/vehicle_prefs.dart';
import '../../../../core/theme/vehicle_sprites.dart';
import '../../../../core/utils/marker_factory.dart';

/// Renders the map's marker icons as canvas-drawn PNG bytes, ready to be
/// registered with the MapLibre style via `addImage`. Kept separate from
/// the map widget so the drawing code stays in one cohesive place.
class MapMarkerRenderer {
  MapMarkerRenderer._();

  /// Depot (trip start) — a solid brand-green dot with a flag glyph.
  static Future<Uint8List> depot() => _toPng(34, 34, (c, sz) {
    _dot(c, sz, fill: AppColors.primary, r: 10);
    _glyph(
      c,
      sz,
      String.fromCharCode(Icons.flag_rounded.codePoint),
      fontSize: 12,
      color: AppColors.white,
    );
  });

  /// Numbered stop. [visit] colours it by sim/drive progress (null = a
  /// plain not-yet-played stop); [optional] tints active optionals amber.
  static Future<Uint8List> stop(
    int index,
    StopVisitState? visit, {
    bool optional = false,
  }) => _toPng(34, 34, (c, sz) {
    switch (visit) {
      case null:
        _dot(
          c,
          sz,
          fill: optional ? AppColors.optional : AppColors.accent,
          r: 10,
        );
        _glyph(
          c,
          sz,
          '$index',
          fontSize: 11,
          color: AppColors.white,
          fontFamily: 'Almarai',
          fontWeight: FontWeight.w800,
        );
      case StopVisitState.upcoming:
        _dot(c, sz, fill: AppColors.white, border: AppColors.primary, r: 10);
        _glyph(
          c,
          sz,
          '$index',
          fontSize: 11,
          color: AppColors.primary,
          fontFamily: 'Almarai',
          fontWeight: FontWeight.w800,
        );
      case StopVisitState.visiting:
        _dot(
          c,
          sz,
          fill: AppColors.pinOrange,
          r: 13,
          glow: AppColors.pinOrange,
        );
        _glyph(
          c,
          sz,
          '$index',
          fontSize: 11,
          color: AppColors.white,
          fontFamily: 'Almarai',
          fontWeight: FontWeight.w800,
        );
      case StopVisitState.visited:
        _dot(c, sz, fill: AppColors.primary, r: 10);
        _glyph(
          c,
          sz,
          String.fromCharCode(Icons.check_rounded.codePoint),
          fontSize: 13,
          color: AppColors.white,
        );
    }
  });

  /// Deactivated optional stop — a muted, hollow dot so it reads as
  /// "parked / not in the route" without disappearing from the map.
  static Future<Uint8List> optionalOff() => _toPng(30, 30, (c, sz) {
    _dot(c, sz, fill: AppColors.white, border: AppColors.optionalOff, r: 8);
    _glyph(
      c,
      sz,
      String.fromCharCode(Icons.pause_rounded.codePoint),
      fontSize: 12,
      color: AppColors.optionalOff,
    );
  });

  /// The animated playback / drive vehicle — whichever [VehicleKind] the
  /// user picked in Settings (top-down, drawn pointing north).
  static Future<Uint8List> vehicle() async {
    final kind = VehiclePrefs.current;
    final sprite = await VehicleSprites.of(kind);
    return _toPng(44, 44, (c, sz) => _paintVehicle(c, sz, kind, sprite));
  }

  /// Geo-anchored drive vehicle used while the user freely explores the map
  /// mid-navigation. Drawn exactly like the screen-fixed `NavigationPuck`
  /// (halo + soft shadow + the picked vehicle) so swapping between the two
  /// is invisible.
  static Future<Uint8List> navVehicle() async {
    final kind = VehiclePrefs.current;
    final sprite = await VehicleSprites.of(kind);
    return _toPng(54, 54, (c, sz) {
      _paintNavHalo(c, sz);
      _paintVehicle(c, sz, kind, sprite);
    });
  }

  /// One pseudo-3D frame of the picked vehicle's nav sheet ([heading] ×
  /// [phase] — see [VehicleNavSheet]), rasterised at
  /// [VehicleMarkerConfig.iconOversample]× the logical marker size so the
  /// symbol stays crisp on high-DPR screens (drawn with
  /// `iconSize: dpr / iconOversample`). [halo] adds the explore-mode
  /// halo + soft shadow chrome. Falls back to the flat top-down sprite
  /// when the kind has no baked sheet.
  static Future<Uint8List> navFrame(
    int heading,
    int phase, {
    required bool halo,
  }) async {
    final kind = VehiclePrefs.current;
    final sheet = await VehicleSprites.navOf(kind);
    final sprite = sheet == null ? await VehicleSprites.of(kind) : null;
    final logical = halo ? 54.0 : 44.0;
    const os = VehicleMarkerConfig.iconOversample;
    return _toPng(logical * os, logical * os, (c, _) {
      c.scale(os, os);
      final sz = ui.Size(logical, logical);
      if (halo) _paintNavHalo(c, sz);
      if (sheet == null) {
        _paintVehicle(c, sz, kind, sprite);
        return;
      }
      c.drawImageRect(
        sheet,
        VehicleNavSheet.frameRect(sheet, heading, phase),
        Rect.fromLTWH(0, 0, sz.width, sz.height),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    });
  }

  /// Halo + soft ground shadow under the drive avatar (shared by
  /// [navVehicle] and the [navFrame] halo variant; the frame's own baked
  /// shadow is subtle, so the chrome keeps the swap with the Flutter puck
  /// invisible).
  static void _paintNavHalo(ui.Canvas c, ui.Size sz) {
    final center = Offset(sz.width / 2, sz.height / 2);
    c.drawCircle(
      center,
      26,
      ui.Paint()..color = AppColors.primary.withValues(alpha: 0.10),
    );
    c.drawOval(
      Rect.fromCenter(center: center.translate(0, 6), width: 34, height: 38),
      ui.Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
  }

  /// Draws [kind]'s avatar into the full [sz] square: the decoded 3D
  /// sprite when available, else its code painter (the arrow).
  static void _paintVehicle(
    Canvas c,
    Size sz,
    VehicleKind kind,
    ui.Image? sprite,
  ) {
    if (sprite == null) {
      kind.painter()?.paint(c, sz);
      return;
    }
    c.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      Rect.fromLTWH(0, 0, sz.width, sz.height),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  /// The user's current location — a haloed blue dot.
  static Future<Uint8List> userLocation() => _toPng(32, 32, (c, sz) {
    final center = Offset(sz.width / 2, sz.height / 2);
    c.drawCircle(
      center,
      11,
      ui.Paint()..color = AppColors.primary.withValues(alpha: 0.15),
    );
    c.drawCircle(
      Offset(center.dx, center.dy + 1),
      6,
      ui.Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
    );
    c.drawCircle(center, 6, ui.Paint()..color = AppColors.primary);
    c.drawCircle(
      center,
      6,
      ui.Paint()
        ..color = AppColors.white
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  });

  // ── Drawing primitives ───────────────────────────────────────────────

  static Future<Uint8List> _toPng(
    double w,
    double h,
    void Function(ui.Canvas, ui.Size) painter,
  ) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    painter(canvas, ui.Size(w, h));
    final pic = rec.endRecording();
    final img = await pic.toImage(w.round(), h.round());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bd!.buffer.asUint8List();
  }

  /// A filled circle with an optional glow or drop-shadow and a white border.
  static void _dot(
    ui.Canvas c,
    ui.Size sz, {
    required Color fill,
    Color border = AppColors.white,
    required double r,
    Color? glow,
  }) {
    final center = Offset(sz.width / 2, sz.height / 2);
    if (glow != null) {
      c.drawCircle(
        center,
        r + 2,
        ui.Paint()
          ..color = glow.withValues(alpha: 0.55)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
    } else {
      c.drawCircle(
        Offset(sz.width / 2, sz.height / 2 + 1.5),
        r,
        ui.Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
      );
    }
    c.drawCircle(center, r, ui.Paint()..color = fill);
    c.drawCircle(
      center,
      r,
      ui.Paint()
        ..color = border
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  /// Paints text (or an icon glyph) centred in [sz].
  static void _glyph(
    ui.Canvas c,
    ui.Size sz,
    String text, {
    required double fontSize,
    required Color color,
    String fontFamily = 'MaterialIcons',
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      c,
      Offset(sz.width / 2 - tp.width / 2, sz.height / 2 - tp.height / 2),
    );
  }
}
