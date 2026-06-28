part of 'route_simulation_overlay.dart';

/// A video-player-style trip scrubber: a track with the elapsed portion filled,
/// little ticks at each stop, and a draggable playhead shaped like the preview
/// car. Drag (or tap) anywhere to scrub the trip — pauses playback so the user
/// can park on a stretch and replay it.
class _TripScrubber extends StatefulWidget {
  final double progress;
  final List<double> stops;
  final double totalMinutes;
  final ValueChanged<double> onSeek;

  const _TripScrubber({
    required this.progress,
    required this.stops,
    required this.totalMinutes,
    required this.onSeek,
  });

  @override
  State<_TripScrubber> createState() => _TripScrubberState();
}

class _TripScrubberState extends State<_TripScrubber> {
  bool _dragging = false;

  static const double _trackHeight = 34;
  static const double _carSize = 30;

  String _fmt(double minutes) {
    if (minutes <= 0) return '--:--';
    final total = (minutes * 60).round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  void _seekTo(double dx, double width) {
    if (width <= 0) return;
    widget.onSeek((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(widget.totalMinutes * p), style: AppTextStyles.mutedSm),
              Text(_fmt(widget.totalMinutes), style: AppTextStyles.mutedSm),
            ],
          ),
        ),
        const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                HapticFeedback.selectionClick();
                _seekTo(d.localPosition.dx, w);
              },
              onHorizontalDragStart: (d) {
                setState(() => _dragging = true);
                _seekTo(d.localPosition.dx, w);
              },
              onHorizontalDragUpdate: (d) => _seekTo(d.localPosition.dx, w),
              onHorizontalDragEnd: (_) {
                HapticFeedback.selectionClick();
                setState(() => _dragging = false);
              },
              child: SizedBox(
                height: _trackHeight,
                width: w,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScrubberTrackPainter(
                          progress: p,
                          stops: widget.stops,
                        ),
                      ),
                    ),
                    // The car playhead rides the track at the current position.
                    Positioned(
                      left: (p * w) - _carSize / 2,
                      top: (_trackHeight - _carSize) / 2,
                      child: AnimatedScale(
                        scale: _dragging ? 1.18 : 1,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        child: Transform.rotate(
                          angle: math.pi / 2, // nose points along travel (right)
                          child: const SizedBox(
                            width: _carSize,
                            height: _carSize,
                            child: CustomPaint(painter: TopViewCarPainter()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScrubberTrackPainter extends CustomPainter {
  final double progress;
  final List<double> stops;

  _ScrubberTrackPainter({required this.progress, required this.stops});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const h = 7.0;
    final r = const Radius.circular(99);

    // Unplayed track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - h / 2, size.width, h),
        r,
      ),
      Paint()..color = AppColors.surfaceDim,
    );

    // Played portion.
    final px = (progress.clamp(0.0, 1.0)) * size.width;
    if (px > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - h / 2, px, h), r),
        Paint()..color = AppColors.primary,
      );
    }

    // Stop ticks.
    for (final f in stops) {
      final x = f * size.width;
      final passed = f <= progress;
      canvas.drawCircle(
        Offset(x, cy),
        3.4,
        Paint()..color = AppColors.white,
      );
      canvas.drawCircle(
        Offset(x, cy),
        2.2,
        Paint()..color = passed ? AppColors.primaryDark : AppColors.borderStrong,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrubberTrackPainter old) =>
      old.progress != progress || old.stops != stops;
}

class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool finished;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  const _PlayPauseButton({
    required this.playing,
    required this.finished,
    required this.onPlay,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final icon = finished
        ? Iconsax.refresh
        : playing
        ? Iconsax.pause
        : Iconsax.play;

    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          playing ? onPause() : onPlay();
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.white, size: 28),
        ),
      ),
    );
  }
}

/// Compact 3-way camera switch for the trip preview: Overview (fit every
/// point on screen — #1), Follow (track the vehicle), Chase (3D view).
class _CameraModeToggle extends StatelessWidget {
  final SimulationCameraMode mode;
  final ValueChanged<SimulationCameraMode> onChanged;

  const _CameraModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 99,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CameraModeButton(
            icon: Icons.zoom_out_map_rounded,
            tooltip: AppStrings.cameraOverview,
            selected: mode == SimulationCameraMode.overview,
            onTap: () => onChanged(SimulationCameraMode.overview),
          ),
          _CameraModeButton(
            icon: Icons.my_location_rounded,
            tooltip: AppStrings.cameraFollow,
            selected: mode == SimulationCameraMode.follow,
            onTap: () => onChanged(SimulationCameraMode.follow),
          ),
          _CameraModeButton(
            icon: Icons.threed_rotation_rounded,
            tooltip: AppStrings.cameraChase,
            selected: mode == SimulationCameraMode.chase,
            onTap: () => onChanged(SimulationCameraMode.chase),
          ),
        ],
      ),
    );
  }
}

class _CameraModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _CameraModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallControl extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SmallControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
