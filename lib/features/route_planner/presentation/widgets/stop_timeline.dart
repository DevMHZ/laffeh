import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/route_point.dart';

/// Frosted-glass panel used by the trip overlays (preview + drive).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Horizontal "subway map" of the trip: one dot per stop, joined by a
/// line. Visited stops are filled green with a check, the current
/// target pulses, upcoming stops are outlined. Makes "where am I in
/// the trip" readable at a glance — even at arm's length in a car.
class StopTimeline extends StatefulWidget {
  /// Ordered trip points (may include the return-to-depot duplicate
  /// at the end).
  final List<RoutePoint> points;

  /// Index (into [points]) of the stop currently being driven to.
  /// Everything before it is shown as done.
  final int currentTarget;

  /// When true the whole trip is done — every dot renders as visited.
  final bool finished;

  /// Tighter sizing for the drive HUD, where vertical space is scarce.
  final bool compact;

  const StopTimeline({
    super.key,
    required this.points,
    required this.currentTarget,
    this.finished = false,
    this.compact = false,
  });

  @override
  State<StopTimeline> createState() => _StopTimelineState();
}

class _StopTimelineState extends State<StopTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final ScrollController _scroll = ScrollController();

  double get _itemExtent => widget.compact ? 48 : 56;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StopTimeline old) {
    super.didUpdateWidget(old);
    if (old.currentTarget != widget.currentTarget) _centerOnTarget();
  }

  /// Keep the active stop visible in the middle of the strip.
  void _centerOnTarget() {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (widget.currentTarget * _itemExtent) -
        (viewport - _itemExtent) / 2;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    return SizedBox(
      height: widget.compact ? 46 : 58,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: points.length,
        itemExtent: _itemExtent,
        itemBuilder: (context, i) {
          final p = points[i];
          final isReturn = i == points.length - 1 && p.isDepot && i != 0;
          final done = widget.finished || i < widget.currentTarget;
          final active = !widget.finished && i == widget.currentTarget;

          return _TimelineItem(
            label: isReturn
                ? Iconsax.repeat
                : p.isDepot
                ? Iconsax.flag
                : null,
            number: p.isDepot ? null : _stopNumber(points, i),
            caption: p.label,
            done: done,
            active: active,
            pulse: _pulse,
            compact: widget.compact,
            drawLeftLine: i > 0,
            drawRightLine: i < points.length - 1,
            leftDone: widget.finished || i <= widget.currentTarget,
            rightDone: widget.finished || i < widget.currentTarget,
          );
        },
      ),
    );
  }

  /// 1-based stop number, skipping depot entries.
  int _stopNumber(List<RoutePoint> points, int index) {
    var n = 0;
    for (var i = 0; i <= index; i++) {
      if (!points[i].isDepot) n++;
    }
    return n;
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData? label;
  final int? number;
  final String caption;
  final bool done;
  final bool active;
  final Animation<double> pulse;
  final bool drawLeftLine;
  final bool drawRightLine;
  final bool leftDone;
  final bool rightDone;
  final bool compact;

  const _TimelineItem({
    required this.label,
    required this.number,
    required this.caption,
    required this.done,
    required this.active,
    required this.pulse,
    required this.drawLeftLine,
    required this.drawRightLine,
    required this.leftDone,
    required this.rightDone,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.primary
        : active
        ? AppColors.pinOrange
        : AppColors.borderStrong;

    final dot = compact ? 22.0 : 27.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 26 : 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Connector lines.
              Row(
                children: [
                  Expanded(
                    child: drawLeftLine
                        ? Container(
                            height: 3,
                            color: leftDone
                                ? AppColors.primary
                                : AppColors.surfaceDim,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: drawRightLine
                        ? Container(
                            height: 3,
                            color: rightDone
                                ? AppColors.primary
                                : AppColors.surfaceDim,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              // The dot.
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  final scale = active ? 1.0 + pulse.value * 0.12 : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active ? color : AppColors.surface,
                        // Upcoming = green ring on white, same as the
                        // map dots during playback.
                        border: Border.all(
                          color: done || active
                              ? AppColors.white
                              : AppColors.primary,
                          width: 2,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: 0.45 - pulse.value * 0.2,
                                  ),
                                  blurRadius: 10 + pulse.value * 6,
                                  spreadRadius: 1 + pulse.value * 2,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      // Depot entries show their icon (flag / repeat).
                      // Regular stops always show their number — green
                      // fill communicates "done", no checkmark overlay.
                      child: label != null
                          ? Icon(
                              label,
                              size: compact ? 11 : 13,
                              color: (done || active)
                                  ? AppColors.white
                                  : AppColors.primary,
                            )
                          : Text(
                              '$number',
                              style: AppTextStyles.titleSm.copyWith(
                                fontSize: compact ? 11 : 12,
                                color: (done || active)
                                    ? AppColors.white
                                    : AppColors.primary,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 2 : 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.mutedSm.copyWith(
              fontSize: compact ? 9 : 10,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
