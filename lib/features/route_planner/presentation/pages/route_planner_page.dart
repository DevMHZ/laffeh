import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/share_intent_handler.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/route_point.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../utils/route_csv_utils.dart';
import '../widgets/center_pin_widget.dart';
import '../widgets/map_action_button.dart';
import '../widgets/route_map_view.dart';
import '../widgets/route_navigation_overlay.dart';
import '../widgets/route_points_sheet.dart';
import '../widgets/route_simulation_overlay.dart';
import '../widgets/route_summary_sheet.dart';

/// Map-first route planner.
///
/// Layout:
///   * Full-screen [RouteMapView] underneath.
///   * Top bar: saved routes / settings + a Stops→Route→Drive step
///     indicator so the user always knows where they are in the trip.
///   * A big floating "Add stop here" pill tied to the crosshair —
///     the one obvious way to place points.
///   * Draggable bottom sheet for [RoutePointsSheet] (before
///     optimization) and [RouteSummarySheet] (after).
///   * Full-screen overlays for trip preview
///     ([RouteSimulationOverlay]) and drive mode
///     ([RouteNavigationOverlay]) — the map stays the hero.
class RoutePlannerPage extends StatelessWidget {
  const RoutePlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RoutePlannerCubit>(
      create: (_) => sl<RoutePlannerCubit>()..initialize(),
      child: const _RoutePlannerView(),
    );
  }
}

class _RoutePlannerView extends StatefulWidget {
  const _RoutePlannerView();

  @override
  State<_RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<_RoutePlannerView> {
  final GlobalKey<RouteMapViewState> _mapKey = GlobalKey<RouteMapViewState>();
  StreamSubscription<String>? _shareSub;

  @override
  void initState() {
    super.initState();
    _shareSub = ShareIntentHandler.stream.listen(_onSharedText);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _onSharedText(String text) async {
    if (!mounted) return;
    final cubit = context.read<RoutePlannerCubit>();
    EasyLoading.show(status: AppStrings.searchingAddresses);
    final count = await cubit.addPointsFromText(text);
    EasyLoading.dismiss();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.pointsAdded(count))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // A Stack sizes itself to its largest NON-positioned child.
          // During preview/drive every non-positioned child here is a
          // SizedBox.shrink, which would collapse the Stack (and the
          // Positioned.fill map with it) to 0×0 — a white screen.
          // This expand keeps the Stack full-screen in every state.
          const SizedBox.expand(),
          Positioned.fill(child: RouteMapView(key: _mapKey)),
          const _TopBar(),
          const _SideActions(),
          _CenterPin(mapKey: _mapKey),
          _BottomSheetHost(mapKey: _mapKey),
          const _TripOverlayHost(),
          const _LoadingOverlay(),
        ],
      ),
    );
  }
}

/// Pushes the saved-routes page and, if the user picked one, loads
/// it back into the planner cubit.
Future<void> _openSavedRoutes(BuildContext context) async {
  final cubit = context.read<RoutePlannerCubit>();
  final picked = await Navigator.of(context).push<SavedRoute>(
    MaterialPageRoute(builder: (_) => const SavedRoutesPage()),
  );
  if (picked != null) {
    cubit.loadSavedRoute(picked);
  }
}

/// Shows a dialog to paste multiple addresses (one per line).
Future<void> _showPasteAddressesDialog(
  BuildContext context,
  RoutePlannerCubit cubit,
) async {
  final controller = TextEditingController();

  // Try to pre-fill from clipboard.
  try {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
      controller.text = clip.text!;
    }
  } catch (_) {}

  if (!context.mounted) return;

  final text = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.95 + (0.05 * curved.value),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogCtx, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 36,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.document_copy,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.pasteAddresses,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.pasteAddressesHint,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 3,
                  style: AppTextStyles.bodyLg,
                  decoration: InputDecoration(
                    hintText: AppStrings.pasteAddressesPlaceholder,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(null),
                        child: Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogCtx).pop(controller.text),
                        icon: const Icon(Iconsax.add_circle, size: 18),
                        label: Text(AppStrings.addPoints),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (text == null || text.trim().isEmpty) return;

  EasyLoading.show(status: AppStrings.searchingAddresses);
  final count = await cubit.addPointsFromText(text);
  EasyLoading.dismiss();
  if (context.mounted) {
    final msg = AppStrings.pointsAdded(count);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

Future<void> _importCsv(BuildContext context, RoutePlannerCubit cubit) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    final path = file.path;
    if (bytes == null && path == null) {
      throw const FormatException('CSV file has no readable content');
    }
    final text = bytes != null
        ? utf8.decode(bytes)
        : await File(path!).readAsString();

    final lines = RouteCsvUtils.decodeImportLines(text);
    if (lines.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.csvImportEmpty)));
      }
      return;
    }

    EasyLoading.show(status: AppStrings.searchingAddresses);
    final count = await cubit.addPointsFromText(lines.join('\n'));
    EasyLoading.dismiss();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.pointsAdded(count))));
    }
  } catch (_) {
    EasyLoading.dismiss();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.csvImportFailed)));
    }
  }
}

Future<void> _exportCsv(BuildContext context, List<RoutePoint> points) async {
  if (points.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.csvNoPoints)));
    return;
  }

  try {
    final csv = RouteCsvUtils.encodePoints(points);
    final dir = await getTemporaryDirectory();
    final fileName = 'laffeh_route_${_timestampForFile(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      text: AppStrings.csvShareText,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.csvExportFailed)));
    }
  }
}

String _timestampForFile(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
}

List<RoutePoint> _csvPointsForState(RoutePlannerState state) {
  final points = state.optimizedRoute?.orderedPoints ?? state.points;
  return RouteCsvUtils.stripReturnDuplicate(points);
}

void _launchGoogleMaps(List<RoutePoint> points) {
  if (points.length < 2) return;
  final origin = points.first;
  final destination = points.last;
  final waypoints = points.length > 2
      ? points
            .sublist(1, points.length - 1)
            .map((p) => '${p.latitude},${p.longitude}')
            .join('|')
      : null;

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    if (waypoints != null) 'waypoints': waypoints,
    'travelmode': 'driving',
  });
  launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        // The trip overlays own the top of the screen.
        if (state.simulationActive || state.navigationActive) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  _Glass(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    child: _TopIconButton(
                      tooltip: AppStrings.savedRoutes,
                      icon: Iconsax.archive_book,
                      onPressed: () => _openSavedRoutes(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _StepIndicator(
                        step: state.hasOptimizedRoute ? 1 : 0,
                      ),
                    ),
                  ),
                  _Glass(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    child: _TopIconButton(
                      tooltip: AppStrings.settings,
                      icon: Iconsax.setting_2,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slim Stops → Route → Drive progress chip. Always tells the user
/// which phase of the trip they're in and what comes next.
class _StepIndicator extends StatelessWidget {
  /// 0 = adding stops, 1 = route ready, 2 = driving.
  final int step;

  const _StepIndicator({required this.step});

  static List<String> get _labels => [
    AppStrings.stepStops,
    AppStrings.stepRoute,
    AppStrings.stepDrive,
  ];

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Container(
                width: 14,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppColors.primary
                      : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            _StepDot(
              index: i,
              label: _labels[i],
              done: i < step,
              active: i == step,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool active;

  const _StepDot({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.surfaceDim,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.white)
          : Text(
              '${index + 1}',
              style: AppTextStyles.mutedSm.copyWith(
                color: active ? AppColors.white : AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
    );

    // Only the active step shows its label — keeps the chip compact
    // in all three languages.
    if (!active) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.titleSm.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        minimumSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      icon: Icon(icon, color: AppColors.textPrimary, size: 22),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.60),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Fixed pin in the centre of the map plus the one obvious way to
/// place a point: a big labelled pill right under the crosshair.
/// Asphalt while the departure is missing, brand green afterwards —
/// the pill text switches with it ("Set departure here" → "Add stop
/// here"), so the next action is always spelled out.
class _CenterPin extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;

  const _CenterPin({required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.optimizedRoute != b.optimizedRoute ||
          a.status != b.status ||
          a.points.isEmpty != b.points.isEmpty,
      builder: (context, state) {
        final visible =
            !state.simulationActive &&
            !state.navigationActive &&
            !state.hasOptimizedRoute &&
            !state.isOptimizing;
        if (!visible) return const SizedBox.shrink();
        final hasDepot = state.points.isNotEmpty;
        final color = hasDepot ? AppColors.primary : AppColors.asphalt;

        return Stack(
          children: [
            Center(
              child: IgnorePointer(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, value, __) =>
                      CenterPinWidget(color: value ?? color),
                ),
              ),
            ),
            // The add pill, tied visually to the crosshair above it.
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, 64),
                child: _AddHerePill(
                  color: color,
                  icon: hasDepot ? Iconsax.location_add : Iconsax.flag,
                  label: hasDepot
                      ? AppStrings.addStopHere
                      : AppStrings.setDepartureHere,
                  onTap: () {
                    final mapState = mapKey.currentState;
                    if (mapState == null) return;
                    context.read<RoutePlannerCubit>().addPoint(
                      mapState.mapCenter,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddHerePill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddHerePill({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.85),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.white, size: 19),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts the full-screen trip overlays (preview + drive). Lives above
/// the bottom sheet in the stack; renders nothing while planning.
class _TripOverlayHost extends StatelessWidget {
  const _TripOverlayHost();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive,
      builder: (context, state) {
        if (state.navigationActive) {
          return RouteNavigationOverlay(
            onOpenGoogleMaps: () {
              final route = context
                  .read<RoutePlannerCubit>()
                  .state
                  .optimizedRoute;
              if (route != null) _launchGoogleMaps(route.orderedPoints);
            },
          );
        }
        if (state.simulationActive) return const RouteSimulationOverlay();
        return const SizedBox.shrink();
      },
    );
  }
}

class _SideActions extends StatelessWidget {
  const _SideActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        if (state.simulationActive || state.navigationActive) {
          return const SizedBox.shrink();
        }
        final cubit = context.read<RoutePlannerCubit>();

        return AnimatedPositionedDirectional(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          bottom: _railBottom(context, state),
          end: 14,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Column(
              key: ValueKey('gps-${state.hasOptimizedRoute}'),
              children: [
                MapActionButton(
                  icon: Iconsax.gps,
                  tooltip: AppStrings.yourLocation,
                  onPressed: cubit.initialize,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _railBottom(BuildContext context, RoutePlannerState state) {
    final height = MediaQuery.sizeOf(context).height;
    final topSafe = MediaQuery.paddingOf(context).top;
    final sheetFraction = state.hasOptimizedRoute ? 0.55 : 0.42;
    final railAllowance = state.hasOptimizedRoute ? 142.0 : 250.0;
    final maxBottom = height - topSafe - railAllowance;
    return (height * sheetFraction + 16).clamp(232.0, maxBottom);
  }
}

class _BottomSheetHost extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;

  const _BottomSheetHost({required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.points != b.points ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();
        // Trip preview and drive mode use full-screen overlays
        // (_TripOverlayHost) — no sheet at all.
        if (state.simulationActive || state.navigationActive) {
          return const SizedBox.shrink();
        }
        final showSummary = state.hasOptimizedRoute;

        final key = showSummary ? 'summary' : 'points';

        // ────────────────────────────────────────────────
        // Snap sizes are intentionally tight to content.
        //   * `min`     — peek; user sees the title + 1-2 lines.
        //   * `initial` — comfortable default for the screen.
        //   * `max`     — capped per sheet so the user can't drag
        //                 past where there's actually content.
        //                 No more "empty void" under the list.
        // The opaque Material below ensures even if max > content,
        // the gap is rendered as the same surface color (no map
        // bleed-through).
        // ────────────────────────────────────────────────
        final config = showSummary
            ? const _SheetConfig(
                min: 0.28,
                initial: 0.55,
                max: 0.85,
                snaps: [0.28, 0.55, 0.85],
              )
            : const _SheetConfig(
                min: 0.24,
                initial: 0.42,
                max: 0.68,
                snaps: [0.24, 0.42, 0.68],
              );

        return DraggableScrollableSheet(
          key: ValueKey(key),
          initialChildSize: config.initial,
          minChildSize: config.min,
          maxChildSize: config.max,
          snap: true,
          snapSizes: config.snaps,
          builder: (context, scrollController) {
            return Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              elevation: 10,
              shadowColor: AppColors.shadow,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.97),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: showSummary
                        ? RouteSummarySheet(
                            onOpenGoogleMaps: () => _launchGoogleMaps(
                              state.optimizedRoute!.orderedPoints,
                            ),
                            onExportCsv: () =>
                                _exportCsv(context, _csvPointsForState(state)),
                          )
                        : RoutePointsSheet(
                            onAddPoint: () {
                              final mapState = mapKey.currentState;
                              if (mapState == null) return;
                              cubit.addPoint(mapState.mapCenter);
                            },
                            onPasteAddresses: () =>
                                _showPasteAddressesDialog(context, cubit),
                            onImportCsv: () => _importCsv(context, cubit),
                            onExportCsv: state.hasPoints
                                ? () => _exportCsv(
                                    context,
                                    _csvPointsForState(state),
                                  )
                                : null,
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SheetConfig {
  final double min;
  final double initial;
  final double max;
  final List<double> snaps;
  const _SheetConfig({
    required this.min,
    required this.initial,
    required this.max,
    required this.snaps,
  });
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        if (!state.isOptimizing) return const SizedBox.shrink();
        return AppLoadingOverlay(message: AppStrings.bestRouteTitle);
      },
    );
  }
}
