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
      if (context.mounted && notifier.value != value) notifier.value = value;
    });
  }
}

/// Publishes its child's height to [SheetExtent], as a fraction of the screen.
///
/// The draggable planner sheet reports its own extent for free, because that
/// is what a [DraggableScrollableSheet] does. Every *other* thing that sits
/// along the bottom edge — the preview scrubber, the single-destination card
/// — is an ordinary widget of whatever height its content came to, and
/// reports nothing. Wrapping one in this makes it speak the same language,
/// so the map chrome clears it too instead of guessing with a constant.
///
/// Measured rather than hard-coded because these bars change height with
/// their content and with the device's bottom inset, and a constant that is
/// right on one phone is wrong on the next.
class ReportsExtent extends StatefulWidget {
  final Widget child;

  const ReportsExtent({super.key, required this.child});

  @override
  State<ReportsExtent> createState() => _ReportsExtentState();
}

class _ReportsExtentState extends State<ReportsExtent> {
  final GlobalKey _key = GlobalKey();
  InheritedElement? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = context.getElementForInheritedWidgetOfExactType<SheetExtent>();
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ReportsExtent old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void dispose() {
    // The bar is leaving the screen; anything still reading the extent
    // should fall back to its own floor rather than hold this bar's height.
    // Cache the scope while mounted: ancestor lookups during dispose are
    // invalid, and the planner may dispose its notifier in this same frame.
    final scope = _scope;
    final notifier = (scope?.widget as SheetExtent?)?.notifier;
    if (notifier != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scope!.mounted) notifier.value = 0;
      });
    }
    super.dispose();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      final screen = MediaQuery.maybeSizeOf(context)?.height ?? 0;
      if (box == null || !box.hasSize || screen <= 0) return;
      SheetExtent.publish(context, box.size.height / screen);
    });
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
