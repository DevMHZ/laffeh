part of 'offline_area_picker_page.dart';

/// The summary under the map: what the frame covers, what it costs, and the
/// one button that spends it.
///
/// Takes plain numbers rather than reading the map, so it renders — and can
/// be reviewed — with no platform behind it.
class OfflineAreaPickerCard extends StatelessWidget {
  final MapPackController pack;

  /// Ground the frame covers. Null until the map has reported a camera.
  final double? widthKm;
  final double? heightKm;

  /// What the framed area would cost now.
  final double estimateMb;

  /// What it cost when download was pressed — the denominator under the
  /// progress bar, so it stays the number the driver agreed to even though
  /// they can keep panning the map behind it.
  final double quotedMb;

  /// True when the frame holds more than one download may carry.
  final bool tooLarge;

  /// True when a *new* area would exceed the saved-areas ceiling.
  final bool atCeiling;

  /// The saved area the frame is sitting on, if any.
  ///
  /// This, and not "is anything stored at all", is what the button reads.
  /// The card used to say "update" whenever the device held any saved map,
  /// which told a driver framing a second city that they were refreshing
  /// the first — while the download would in fact have deleted it.
  final SavedMapArea? savedHere;

  /// How many areas are stored in total, for the line that says so.
  final int savedCount;

  /// Whether [pack]'s status describes the area now framed.
  ///
  /// The controller is a singleton holding the last download's outcome, so
  /// a half-finished download of one city would otherwise offer to "finish"
  /// a completely different one.
  final bool statusApplies;

  /// Null while there is nothing to download, or nothing sane to.
  final VoidCallback? onDownload;

  /// Null unless the frame sits on a saved area — deleting is always about
  /// *this* area, never about whatever happens to be stored.
  final VoidCallback? onDelete;

  const OfflineAreaPickerCard({
    super.key,
    required this.pack,
    required this.widthKm,
    required this.heightKm,
    required this.estimateMb,
    required this.quotedMb,
    required this.tooLarge,
    required this.onDownload,
    required this.onDelete,
    this.atCeiling = false,
    this.savedHere,
    this.savedCount = 0,
    this.statusApplies = true,
  });

  @override
  Widget build(BuildContext context) {
    final downloading = pack.status == MapPackStatus.downloading;

    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: AppColors.shadow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(),
              const SizedBox(height: 14),
              if (downloading)
                MapPackProgressView(pack: pack, estimatedMb: quotedMb)
              else
                _actions(),
            ],
          ),
        ),
      ),
    );
  }

  /// What is framed, in the two figures worth reading before spending: the
  /// ground it covers and what it costs.
  Widget _summary() {
    final measured = widthKm != null && heightKm != null;
    final here = savedHere;
    final downloading = pack.status == MapPackStatus.downloading;

    // Three different things the second line can be, in the order they
    // matter to someone standing over the map: this exact area is already
    // saved; some other areas are; nothing is, so here is what to do.
    final (String subtitle, Color tint) = switch (0) {
      _ when downloading => (
        AppStrings.offlineAreaPickHint,
        AppColors.textSecondary,
      ),
      _ when here != null => (
        '${AppStrings.offlineAreaSavedHere} · '
            '${AppStrings.megabytes(here.storedMb)}',
        AppColors.success,
      ),
      _ when savedCount > 0 => (
        AppStrings.offlineAreaSavedCount(savedCount),
        AppColors.textSecondary,
      ),
      _ => (AppStrings.offlineAreaPickHint, AppColors.textSecondary),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Iconsax.map, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                measured
                    ? AppStrings.offlineAreaDimensions(widthKm!, heightKm!)
                    : AppStrings.offlineAreaMeasuring,
                style: AppTextStyles.titleMd,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.mutedSm.copyWith(color: tint),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: AppStrings.offlineMapDelete,
            onPressed: onDelete,
            icon: Icon(Iconsax.trash, size: 20, color: AppColors.danger),
          ),
      ],
    );
  }

  Widget _actions() {
    // "Update" is reserved for the one case where it is true: the frame is
    // sitting on an area that is already saved. Anywhere else it is a
    // download, however many other maps the device is holding.
    final status = statusApplies ? pack.status : MapPackStatus.idle;

    final label = switch (status) {
      MapPackStatus.partial => AppStrings.offlineMapRetry,
      MapPackStatus.cancelled => AppStrings.offlineMapResume,
      _ when savedHere != null => AppStrings.offlineAreaUpdate,
      _ => AppStrings.offlineMapDownload,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tooLarge)
          _note(AppStrings.offlineAreaTooLarge, AppColors.warning)
        else if (atCeiling)
          _note(AppStrings.offlineAreaAtCeiling, AppColors.warning)
        else if (status == MapPackStatus.partial)
          _note(AppStrings.offlineMapPartial, AppColors.warning)
        else if (status == MapPackStatus.cancelled)
          // Stopping on purpose is not a failure, and warning colours here
          // would tell the driver they broke something.
          _note(AppStrings.offlineMapCancelled, AppColors.textSecondary)
        else if (status == MapPackStatus.failed)
          _note(AppStrings.offlineMapFailed, AppColors.danger),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Iconsax.import_1, size: 18),
            label: Text(
              // The estimate rides on the button because it is the last
              // thing worth reading before spending the data.
              '$label · ${AppStrings.approxMegabytes(estimateMb)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: AppTextStyles.mutedSm.copyWith(color: color)),
  );
}

/// Dims everything outside the frame and outlines what's inside it.
///
/// The scrim is the part that does the explaining: a bare rectangle on a map
/// reads as decoration, while a map that is bright inside the rectangle and
/// dim outside it says which half is being saved without a word of copy.
class _FramePainter extends CustomPainter {
  final Rect frame;
  final Color border;
  final Color scrim;

  const _FramePainter({
    required this.frame,
    required this.border,
    required this.scrim,
  });

  /// Length of the corner ticks — the frame's edges are thin enough to lose
  /// against busy map detail, and the corners are what the eye reads as
  /// "this is adjustable".
  static const double _tick = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(14));

    // Everything but the frame, in one even-odd path.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      Paint()..color = scrim,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = border.withValues(alpha: 0.9),
    );

    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = border;

    for (final (Offset origin, double dx, double dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      // Inset so the tick sits on the rounded corner's straight run rather
      // than cutting across the curve.
      final start = origin.translate(dx * 8, dy * 2);
      canvas.drawLine(start, start.translate(dx * _tick, 0), corner);
      final startV = origin.translate(dx * 2, dy * 8);
      canvas.drawLine(startV, startV.translate(0, dy * _tick), corner);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.border != border || old.scrim != scrim;
}

/// A round control that stays legible over map detail.
class _MapChipButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback? onTap;

  const _MapChipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.shadowSoft,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
