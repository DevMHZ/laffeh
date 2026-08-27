import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/phone_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/google_glyph.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';
import '../../../onboarding/presentation/widgets/onboarding_mock.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../utils/route_csv_utils.dart';
import '../widgets/add_place_bar.dart';
import '../widgets/route_address_search_sheet.dart';
import '../widgets/route_paste_location_sheet.dart';

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
    if (points.isEmpty) {
      AppToast.show(context, AppStrings.csvNoPoints, tone: ToastTone.info);
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
        AppToast.show(context, AppStrings.csvExportSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          AppStrings.csvExportFailed,
          tone: ToastTone.failure,
        );
      }
    }
  }

  /// Opens a WhatsApp chat with the stop's contact.
  ///
  /// `wa.me` wants bare international digits. A number saved with its country
  /// code works; one saved as a local `0944…` cannot be reached
  /// internationally, and we hand WhatsApp what we have rather than guessing a
  /// country on the driver's behalf — WhatsApp's own "invalid number" is a
  /// clearer answer than us silently dialling the wrong country.
  static Future<void> messageStopOnWhatsapp(
    BuildContext context,
    String phone,
  ) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('https://wa.me/${PhoneUtils.digitsOnly(phone)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      AppToast.show(
        context,
        AppStrings.whatsappOpenFailed,
        tone: ToastTone.failure,
      );
    }
  }

  /// Dials the stop's contact. Unlike `wa.me`, `tel:` is happy with the number
  /// exactly as the driver stored it — a local one included — so nothing is
  /// normalised away here.
  static Future<void> callStop(BuildContext context, String phone) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      AppToast.show(
        context,
        AppStrings.stopCallFailed,
        tone: ToastTone.failure,
      );
    }
  }

  /// Adds one point and confirms it landed.
  ///
  /// The map centres itself — the cubit points `cameraTarget` at the new stop
  /// — so all this owes the driver is the word that it worked. A null return
  /// means a guard swallowed the add (a debounced double-tap, or a pin
  /// dropped on top of an existing stop); confirming that would be a lie.
  static Future<void> addPointConfirmed(
    BuildContext context,
    RoutePlannerCubit cubit,
    LatLng position, {
    String? address,
  }) async {
    final point = await cubit.addPoint(position, address: address);
    if (point == null || !context.mounted) return;
    AppToast.show(context, AppStrings.pointAdded);
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
      AppToast.show(
        context,
        AppStrings.whatsappOpenFailed,
        tone: ToastTone.failure,
      );
    }
  }

  /// Explains how adding a stop *from WhatsApp* works, replaying the very
  /// same animated demo the user saw during onboarding ([OnbWhatsappDemo]).
  /// Strictly WhatsApp — no CSV/paste mention here.
  ///
  /// The steps differ by platform, so the body text does too. Android shares
  /// the location straight to Laffah; iOS has no such route, because WhatsApp's
  /// own "Select an action" sheet is a hard-coded list of map apps that no
  /// third party can join — so there the user goes out through Maps and shares
  /// from *there*, which does reach the Share Extension.
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
                      // The picture has to match the platform for the same
                      // reason the words below it do.
                      child: Platform.isIOS
                          ? const OnbWhatsappDemoIos()
                          : const OnbWhatsappDemo(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                Platform.isIOS
                    ? AppStrings.onbImportTitleIos
                    : AppStrings.onbImportTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 10),
              Text(
                Platform.isIOS
                    ? AppStrings.waInfoBodyIos
                    : AppStrings.waInfoBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              // The demo shows the driver what to do *in WhatsApp*, so the
              // sheet ends by taking them there. Explaining a journey and
              // then leaving them to find the door themselves is half a job.
              _InfoAction(
                label: AppStrings.openWhatsappCta,
                glyph: WhatsappGlyph(size: 20, color: AppColors.white),
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

  /// The same favour for the other app a driver keeps places in.
  ///
  /// Two ways out, because Google Maps offers two: share the place straight
  /// to Laffah (what the demo shows), or copy its link and paste it here —
  /// which is the one that always works, on any phone, from any browser.
  static Future<void> showGoogleMapsInfo(
    BuildContext context,
    RoutePlannerCubit cubit, {

    /// True when the sheet was opened from the departure picker: the pasted
    /// link names where the trip starts, not another stop.
    bool asDeparture = false,
  }) {
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
              SizedBox(
                height: 326,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: const OnbPhoneFrame(child: OnbGoogleMapsDemo()),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.gmapsInfoTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.gmapsInfoBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _InfoAction(
                label: AppStrings.openGoogleMapsCta,
                glyph: const GoogleGlyph(size: 20),
                onTap: () {
                  Navigator.of(ctx).pop();
                  openGoogleMapsApp(context);
                },
              ),
              const SizedBox(height: 10),
              _InfoAction(
                label: AppStrings.pasteLinkCta,
                icon: Iconsax.link,
                primary: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (asDeparture) cubit.expectDepartureImport();
                  showPasteLocationSheet(context, cubit);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens Google Maps itself — the app when it is installed, the site when
  /// it is not.
  ///
  /// iOS answers `canOpenURL` for a third-party scheme only if the app
  /// declares it (see `LSApplicationQueriesSchemes`); Android has no such
  /// scheme, and the plain https link is an app link there, so it opens the
  /// app anyway.
  static Future<void> openGoogleMapsApp(BuildContext context) async {
    if (Platform.isIOS) {
      final app = Uri.parse('comgooglemaps://');
      try {
        if (await canLaunchUrl(app)) {
          await launchUrl(app, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {
        // Fall through to the web address, which needs no permission.
      }
    }
    await launchUrl(
      Uri.parse('https://www.google.com/maps'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// The per-point "how do you want to add this point?" chooser, shown every
  /// time the user adds a stop (first or later). Exactly four ways:
  ///   1. Pick on the map (drops into manual-placement mode with a crosshair).
  ///   2. Type a single address (search + pick one) — never a bulk list.
  ///   3. Paste a Google (or Apple) Maps link — short or full.
  ///   4. Import from WhatsApp (share a location back to Laffah). The route
  ///      there differs per platform — see [showWhatsappInfo].
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
                child: Text(AppStrings.addMethodTitle, style: AppTextStyles.h3),
              ),
              const SizedBox(height: 14),
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
                icon: Iconsax.link,
                iconWidget: const GoogleGlyph(size: 22),
                color: AppColors.info,
                label: AppStrings.methodShortLink,
                subtitle: AppStrings.addMethodPasteLinkSub,
                onTap: () {
                  Navigator.of(ctx).pop();
                  showGoogleMapsInfo(context, cubit);
                },
              ),
              const SizedBox(height: 10),
              _chooserRow(
                icon: Iconsax.message,
                iconWidget: WhatsappGlyph(size: 22, color: AppColors.primary),
                color: AppColors.primary,
                label: AppStrings.addOptWhatsappTitle,
                subtitle: AppStrings.addOptWhatsappSub,
                onTap: () {
                  Navigator.of(ctx).pop();
                  showWhatsappInfo(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Where does this trip start?" — the departure's own sheet.
  ///
  /// The trip starts wherever the driver is standing, and that is right
  /// almost every time, so the app never asks up front. But "almost" is not
  /// "always": a dispatcher building tomorrow's round from a desk, a driver
  /// whose shift starts at the warehouse rather than at home, anyone planning
  /// a trip they are not currently at the start of.
  ///
  /// Naming that place is naming a place — the same job the driver already
  /// knows how to do four ways. So the sheet is the default, stated and
  /// ticked, and then the very same [AddPlaceBar] the rest of the app uses.
  /// A departure picker with its own smaller set of methods would be a second
  /// vocabulary for one idea.
  static Future<void> showDeparturePicker(
    BuildContext context,
    RoutePlannerCubit cubit,
  ) {
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(AppStrings.startFromTitle, style: AppTextStyles.h3),
              ),
              const SizedBox(height: 14),
              _CurrentLocationRow(
                selected: cubit.state.departureIsCurrentLocation,
                onTap: () {
                  Navigator.of(ctx).pop();
                  cubit.useCurrentLocationAsDeparture();
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      AppStrings.orPickAPlace,
                      style: AppTextStyles.mutedSm,
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 14),
              AddPlaceBar(
                // The sheet's own heading already said "start from"; this row
                // says what *it* does.
                title: AppStrings.addMethodAddress,
                floating: false,
                onSearch: () {
                  Navigator.of(ctx).pop();
                  showAddressSearchSheet(
                    context,
                    cubit,
                    title: AppStrings.startFromTitle,
                    // The search sheet adds a stop by default; here the
                    // chosen place has to become the trip's start instead.
                    onPicked: (result) => cubit.setDeparture(
                      result.latLng,
                      address: result.fullLabel,
                    ),
                  );
                },
                onPickOnMap: () {
                  Navigator.of(ctx).pop();
                  cubit.beginManualPlacement(target: PlacementTarget.departure);
                },
                // Both of these end in a place arriving from another app —
                // armed here so the import knows it is the departure.
                onGoogleMaps: () {
                  Navigator.of(ctx).pop();
                  cubit.expectDepartureImport();
                  showGoogleMapsInfo(context, cubit, asDeparture: true);
                },
                onWhatsapp: () {
                  Navigator.of(ctx).pop();
                  cubit.expectDepartureImport();
                  showWhatsappInfo(context);
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
    Widget? trailing,
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
              trailing ??
                  Icon(
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

/// The one action a "here is how it works" sheet ends with. Primary is the
/// hand-off to the other app; the quiet second one is the way that needs no
/// other app at all.
class _InfoAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? glyph;
  final bool primary;
  final VoidCallback onTap;

  const _InfoAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? AppColors.primary
        : AppColors.surfaceAlt.withValues(alpha: 0.8);
    final foreground = primary ? AppColors.white : AppColors.textPrimary;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph ?? Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(color: foreground),
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

/// "Use my current location" — the default the trip already has, offered as
/// a row so the sheet answers "where does this start from?" before it offers
/// to change it. Ticked when it is what the trip is using.
class _CurrentLocationRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CurrentLocationRow({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : AppColors.surfaceAlt.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.useCurrentLocation,
                      style: AppTextStyles.titleSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.useCurrentLocationSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mutedSm,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(Iconsax.tick_circle, size: 22, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
