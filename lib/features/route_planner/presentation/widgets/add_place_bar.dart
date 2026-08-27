import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/google_glyph.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';
import 'glass_panel.dart';

/// The four ways to name a place: search, drop a pin, a Google Maps link, or
/// a location shared from WhatsApp.
///
/// One control, used in both places a driver adds a place — the empty map and
/// the planning sheet. It used to be a search bar on one screen and a single
/// "add a stop" button that opened a chooser on the other, which meant the
/// driver who learned the four ways on their first trip had to find them
/// again, one tap deeper, on every trip after that. The ways in are the same
/// ways in; they should look the same and cost the same.
class AddPlaceBar extends StatelessWidget {
  /// The question the search box asks — "where to?" on an empty map, "add a
  /// stop" once the trip is a round.
  final String title;

  final VoidCallback onSearch;
  final VoidCallback onPickOnMap;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWhatsapp;

  /// True when the bar floats over the live map, where it is frosted glass;
  /// false inside a sheet, where it sits on the sheet's own surface.
  final bool floating;

  const AddPlaceBar({
    super.key,
    required this.title,
    required this.onSearch,
    required this.onPickOnMap,
    required this.onGoogleMaps,
    required this.onWhatsapp,
    this.floating = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(title: title, onTap: onSearch, floating: floating),
        const SizedBox(height: 10),
        // Three equal columns rather than three pills sized to their words:
        // the apps are named in full here ("Google Maps", not "Link"), and a
        // row that shrinks to fit would truncate the very name that tells the
        // driver which app they are about to be handed to.
        Row(
          children: [
            Expanded(
              child: _MethodChip(
                icon: Iconsax.location,
                color: AppColors.warning,
                label: AppStrings.methodShortMap,
                floating: floating,
                onTap: onPickOnMap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MethodChip(
                glyph: const GoogleGlyph(size: 20),
                color: AppColors.info,
                label: AppStrings.methodShortLink,
                floating: floating,
                onTap: onGoogleMaps,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MethodChip(
                glyph: WhatsappGlyph(size: 20, color: AppColors.primary),
                color: AppColors.primary,
                label: AppStrings.methodShortWhatsapp,
                floating: floating,
                onTap: onWhatsapp,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Frosted over the map, plain inside a sheet — the same control either way.
class _Skin extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool floating;

  const _Skin({
    required this.child,
    required this.radius,
    required this.floating,
  });

  @override
  Widget build(BuildContext context) {
    if (floating) {
      return GlassPanel(padding: EdgeInsets.zero, radius: radius, child: child);
    }
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// Looks like a text field, behaves like a button: tapping hands over to the
/// existing address-search sheet, which owns the keyboard, the debounce and
/// the results list. Faking the field here rather than hosting a real one
/// keeps a single search implementation in the app.
class _SearchField extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool floating;

  const _SearchField({
    required this.title,
    required this.onTap,
    required this.floating,
  });

  @override
  Widget build(BuildContext context) {
    return _Skin(
      radius: 18,
      floating: floating,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: floating
                ? const EdgeInsets.fromLTRB(16, 14, 14, 14)
                : const EdgeInsets.fromLTRB(14, 11, 12, 11),
            child: Row(
              children: [
                Icon(Iconsax.search_normal, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.titleMd),
                      // The hint is for the first screen a driver ever sees.
                      // Inside the planning sheet they have already added a
                      // place this way, and the sheet's collapsed peek has to
                      // hold the ways in *and* the optimize button.
                      if (floating) ...[
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.whereToHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mutedSm,
                        ),
                      ],
                    ],
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

/// One of the non-search ways to name a place. Icon-led and narrow on
/// purpose: they are alternatives, not competition for the search box.
class _MethodChip extends StatelessWidget {
  final IconData? icon;
  final Widget? glyph;
  final Color color;
  final String label;
  final bool floating;
  final VoidCallback onTap;

  const _MethodChip({
    this.icon,
    this.glyph,
    required this.color,
    required this.label,
    required this.floating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Skin(
      radius: 14,
      floating: floating,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: floating ? 9 : 7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph ?? Icon(icon, size: 20, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
