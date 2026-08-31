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
///
/// Two pieces, not four cards: the search field, and one panel holding the
/// other three ways with hairlines between them. The three used to be three
/// separate floating cards, and on the empty screen that stack plus the
/// trip-type choice was eating something like two fifths of the phone —
/// which is the map, which is what the driver came for.
///
/// The search field deliberately stays outside that panel. Docked at the top
/// of it, with the same surface and no field of its own, it stopped reading
/// as something you type into and started reading as the panel's heading.
class AddPlaceBar extends StatelessWidget {
  /// What the search field is asking for — "where to?" on an empty map, "add
  /// a stop" once the trip is a round. Written as a placeholder, because
  /// that is what it is.
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
        _Skin(
          radius: 18,
          floating: floating,
          // One ink surface for the three: they are separated by hairlines
          // now, not by gaps, so they no longer carry a Material each.
          child: Material(
            color: Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MethodChip(
                      icon: Iconsax.location,
                      color: AppColors.warning,
                      label: AppStrings.methodShortMap,
                      onTap: onPickOnMap,
                    ),
                  ),
                  const _Rule(),
                  Expanded(
                    child: _MethodChip(
                      glyph: const GoogleGlyph(size: 20),
                      color: AppColors.info,
                      label: AppStrings.methodShortLink,
                      onTap: onGoogleMaps,
                    ),
                  ),
                  const _Rule(),
                  Expanded(
                    child: _MethodChip(
                      glyph: WhatsappGlyph(size: 20, color: AppColors.primary),
                      color: AppColors.primary,
                      label: AppStrings.methodShortWhatsapp,
                      onTap: onWhatsapp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The hairline between two methods — what lets the three share one panel
/// without reading as a wall. Inset top and bottom: a full-height rule would
/// draw a table, and these are buttons in a row.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 9,
      endIndent: 9,
      color: AppColors.divider.withValues(alpha: 0.75),
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
      // Clipped so a row's ink stops at the panel's corners; over the map the
      // glass panel's own clip does this.
      clipBehavior: Clip.antiAlias,
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
///
/// Faking it means it has to *look* faked properly. A bold line of text with
/// an icon beside it is a heading; what makes a search box a search box is
/// the box — a pill of its own, standing clear of everything under it, with
/// grey placeholder text sitting in it waiting to be replaced.
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
      // Near enough to a stadium at this height, which no card in the app is:
      // the shape alone says "type here" before a word is read.
      radius: 24,
      floating: floating,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Icon(
                  Iconsax.search_normal,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Placeholder weight and colour. Bold and black, this
                    // same line read as a title for everything below it.
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
  final VoidCallback onTap;

  const _MethodChip({
    this.icon,
    this.glyph,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
