import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';
import '../../../onboarding/presentation/widgets/onboarding_mock.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../utils/route_csv_utils.dart';
import '../widgets/route_address_search_sheet.dart';

/// Imperative actions invoked from the planner UI — opening saved routes,
/// pasting/importing/exporting points, and handing off to Google Maps.
/// Kept out of the page widget so the page stays declarative.
class RoutePlannerActions {
  RoutePlannerActions._();

  /// Pushes the saved-routes page and loads any picked route into the cubit.
  static Future<void> openSavedRoutes(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final picked = await Navigator.of(context).push<SavedRoute>(
      MaterialPageRoute(builder: (_) => const SavedRoutesPage()),
    );
    if (picked != null) {
      cubit.loadSavedRoute(picked);
    }
  }

  /// Encodes [points] to CSV and opens the share sheet.
  static Future<void> exportCsv(
    BuildContext context,
    List<RoutePoint> points,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (points.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.csvNoPoints)));
      return;
    }

    // Capture the share popover anchor (iPad/macOS need it) before the
    // async gap so we don't touch the context after awaiting.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      final csv = RouteCsvUtils.encodePoints(points);
      final dir = await getTemporaryDirectory();
      final fileName = 'laffeh_route_${_timestampForFile(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      // Write raw UTF-8 bytes (the encoder already embedded a BOM) so Arabic
      // stays readable in Excel.
      await file.writeAsBytes(utf8.encode(csv), flush: true);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: fileName)],
        fileNameOverrides: [fileName],
        text: AppStrings.csvShareText,
        sharePositionOrigin: origin,
      );

      if (context.mounted && result.status == ShareResultStatus.success) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.csvExportSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.csvExportFailed)),
        );
      }
    }
  }

  /// "N points added", or a clear "nothing matched" message for a zero count.
  static String addedMessage(int count) =>
      count > 0 ? AppStrings.pointsAdded(count) : AppStrings.noAddressesFound;

  /// The points to export for [state] — the optimized order if present,
  /// otherwise the raw points, with the duplicated return depot stripped.
  static List<RoutePoint> csvPointsForState(RoutePlannerState state) {
    final points = state.optimizedRoute?.orderedPoints ?? state.points;
    return RouteCsvUtils.stripReturnDuplicate(points);
  }

  /// Opens the route in Google Maps directions.
  static void launchGoogleMaps(List<RoutePoint> points) {
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

  /// Channel to the host app for small native hops (e.g. opening WhatsApp).
  static const MethodChannel _appChannel = MethodChannel('laffeh/app');

  /// Opens the WhatsApp app itself (its main screen, NOT a chat) so the user
  /// can pick a conversation and share a location back to Laffah — the import
  /// is share-driven, handled by [ShareIntentHandler].
  ///
  /// A `wa.me`/`whatsapp://send` link would target a *chat* and fail with
  /// "couldn't open this chat link" when no number is given. So on Android we
  /// launch the package via its launcher intent (native side), and on iOS we
  /// open the bare `whatsapp://` scheme.
  static Future<void> openWhatsapp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      if (Platform.isAndroid) {
        ok = await _appChannel.invokeMethod<bool>('openWhatsapp') ?? false;
      } else {
        ok = await launchUrl(
          Uri.parse('whatsapp://'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.whatsappOpenFailed)),
      );
    }
  }

  /// Explains how adding a stop *from WhatsApp* works, replaying the very
  /// same animated demo the user saw during onboarding ([OnbWhatsappDemo]).
  /// Strictly WhatsApp — no CSV/paste mention here.
  static Future<void> showWhatsappInfo(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The onboarding WhatsApp → map demo, in its phone frame.
              // Keep the frame at its natural 210px width (the demo's inner
              // rows are laid out for that) and let FittedBox scale the whole
              // thing down to the sheet — shrinking the frame itself would
              // overflow those rows.
              SizedBox(
                height: 326,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: OnbPhoneFrame(
                      child: const OnbWhatsappDemo(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.onbImportTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.waInfoBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The per-point "how do you want to add this point?" chooser, shown every
  /// time the user adds a stop (first or later). Exactly three ways:
  ///   1. Type a single address (search + pick one) — never a bulk list.
  ///   2. Pick on the map (drops into manual-placement mode with a crosshair).
  ///   3. Import from WhatsApp (share a location back to Laffah).
  static Future<void> showAddMethodChooser(
    BuildContext context,
    RoutePlannerCubit cubit,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  AppStrings.addMethodTitle,
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 14),
              _chooserRow(
                icon: Iconsax.search_normal,
                color: AppColors.info,
                label: AppStrings.addMethodAddress,
                subtitle: AppStrings.addMethodAddressSub,
                onTap: () {
                  Navigator.of(ctx).pop();
                  showAddressSearchSheet(context, cubit);
                },
              ),
              const SizedBox(height: 10),
              _chooserRow(
                icon: Iconsax.location,
                color: AppColors.warning,
                label: AppStrings.addMethodMap,
                subtitle: AppStrings.addMethodMapSub,
                onTap: () {
                  Navigator.of(ctx).pop();
                  cubit.beginManualPlacement();
                },
              ),
              const SizedBox(height: 10),
              _chooserRow(
                icon: Iconsax.message,
                iconWidget: const WhatsappGlyph(
                  size: 22,
                  color: AppColors.primary,
                ),
                color: AppColors.primary,
                label: AppStrings.addOptWhatsappTitle,
                subtitle: AppStrings.addOptWhatsappSub,
                onTap: () {
                  Navigator.of(ctx).pop();
                  openWhatsapp(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chooserRow({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    Widget? iconWidget,
  }) {
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: iconWidget ?? Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppTextStyles.titleSm),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.mutedSm,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timestampForFile(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}';
  }
}
