import 'package:flutter/material.dart';

/// How much of the screen the bottom sheet currently covers, 0 to 1.
///
/// The map chrome and the sheet are siblings in the planner's stack, so
/// neither can measure the other. This carries the one number between them:
/// the sheet publishes its extent as the driver drags it, and the buttons
/// that must stay clear of it read the same value and ride above.
///
/// Zero means "no sheet on screen" — preview, drive, and pin-placement all
/// take the full map — which lets a reader fall back to the bottom inset
/// rather than floating chrome in mid-air.
class SheetExtent extends InheritedNotifier<ValueNotifier<double>> {
  const SheetExtent({
    super.key,
    required ValueNotifier<double> extent,
    required super.child,
  }) : super(notifier: extent);

  /// The live value, rebuilding the caller as the sheet moves.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SheetExtent>()
          ?.notifier
          ?.value ??
      0;

  /// The notifier itself, for a writer that must not rebuild on every frame
  /// of a drag. Returns null outside a planner screen, which is why every
  /// call site treats publishing as best-effort.
  static ValueNotifier<double>? writerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetExtent>()?.notifier;

  /// Publish [value] after the current build.
  ///
  /// Callers are widgets deciding during *their* build whether a sheet is on
  /// screen at all, and writing to a notifier that others are listening to
  /// would mark them dirty mid-build. Deferring one frame is invisible to the
  /// eye and keeps the frame legal.
  static void publish(BuildContext context, double value) {
    final notifier = writerOf(context);
    if (notifier == null || notifier.value == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notifier.value != value) notifier.value = value;
    });
  }
}
