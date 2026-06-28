import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'route_map_view.dart';

/// Centres [child] (an aim reticle) over the map and nudges it onto the
/// *true* drop point.
///
/// A dropped marker lands at the camera target, which on Android renders a
/// few logical pixels off the widget's geometric centre (see
/// [RouteMapViewState.aimOffset]). Plain `Center` would leave the crosshair
/// sitting beside where points actually land; this listens to the live-
/// measured offset and translates the reticle onto it, so the crosshair, a
/// dropped marker, and the recentred blue dot all coincide on every device.
class AimAlignedReticle extends StatefulWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  final Widget child;

  const AimAlignedReticle({
    super.key,
    required this.mapKey,
    required this.child,
  });

  @override
  State<AimAlignedReticle> createState() => _AimAlignedReticleState();
}

class _AimAlignedReticleState extends State<AimAlignedReticle> {
  ValueListenable<Offset>? _offset;

  @override
  void initState() {
    super.initState();
    // The map's State may not be mounted on this widget's first build, so
    // grab its offset notifier after the frame (retrying until available).
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    if (!mounted || _offset != null) return;
    final notifier = widget.mapKey.currentState?.aimOffset;
    if (notifier != null) {
      setState(() => _offset = notifier);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offset;
    if (offset == null) return Center(child: widget.child);
    return Center(
      child: ValueListenableBuilder<Offset>(
        valueListenable: offset,
        builder: (_, value, child) =>
            Transform.translate(offset: value, child: child),
        child: widget.child,
      ),
    );
  }
}
