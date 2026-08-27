import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/place_suggestion.dart';
import '../pages/route_planner_actions.dart';
import '../cubit/route_planner_cubit.dart';

/// Single-place search: type, pick one match, and the chosen place is added
/// as the next point. One address at a time — there is deliberately no
/// bulk/list paste here.
///
/// [onPicked] takes over what happens to the chosen place. Left null it adds
/// a stop, which is what nearly every caller wants; the departure picker
/// passes its own handler, because the same search has to be able to name
/// where the trip *starts* without dropping a stop there.
/// [title] overrides the sheet's heading to match.
Future<void> showAddressSearchSheet(
  BuildContext context,
  RoutePlannerCubit cubit, {
  void Function(PlaceSuggestion result)? onPicked,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _AddressSearchBody(cubit: cubit, onPicked: onPicked, title: title),
    ),
  );
}

class _AddressSearchBody extends StatefulWidget {
  final RoutePlannerCubit cubit;
  final void Function(PlaceSuggestion result)? onPicked;
  final String? title;

  const _AddressSearchBody({required this.cubit, this.onPicked, this.title});

  @override
  State<_AddressSearchBody> createState() => _AddressSearchBodyState();
}

class _AddressSearchBodyState extends State<_AddressSearchBody> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// The live search. Cancelled the moment the query changes — the previous
  /// query's slow provider must never overwrite the current query's list,
  /// which is the whole reason this is a subscription and not an await.
  StreamSubscription<List<PlaceSuggestion>>? _subscription;

  bool _loading = false;

  /// True between the first results landing and the last source finishing.
  /// Drives a quiet "still looking" line rather than a spinner, because
  /// there is already a usable list on screen by then.
  bool _refining = false;

  List<PlaceSuggestion> _results = const [];
  late final List<PlaceSuggestion> _recents = widget.cubit.recentPlaces();

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _subscription?.cancel();

    final query = value.trim();
    if (query.length < GeocodingConfig.minQueryLength) {
      setState(() {
        _loading = false;
        _refining = false;
        _results = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _refining = false;
    });
    _debounce = Timer(GeocodingConfig.debounce, () => _search(query));
  }

  void _search(String query) {
    _subscription?.cancel();
    _subscription = widget.cubit
        .searchPlaces(query)
        .listen(
          (results) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              // More is still coming; what is on screen is already usable.
              _refining = true;
              _results = results;
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _refining = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _refining = false;
            });
          },
        );
  }

  void _pick(PlaceSuggestion result) {
    HapticFeedback.selectionClick();
    // Remembered on the way out: this is the one signal in the whole search
    // that comes from the driver rather than from a server, and it is what
    // makes the twenty addresses of a regular round instant next week.
    unawaited(widget.cubit.rememberPlace(result));

    // Confirm against the page, not this sheet — the sheet is about to go.
    final host = Navigator.of(context).context;
    final handler = widget.onPicked;
    Navigator.of(context).pop();
    if (handler != null) {
      handler(result);
      return;
    }
    RoutePlannerActions.addPointConfirmed(
      host,
      widget.cubit,
      result.latLng,
      address: result.fullLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? AppStrings.addressSearchTitle,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                final q = v.trim();
                if (q.length >= GeocodingConfig.minQueryLength) _search(q);
              },
              style: AppTextStyles.bodyLg,
              decoration: InputDecoration(
                prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Iconsax.close_circle, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                hintText: AppStrings.addressSearchPlaceholder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Flexible, not just capped: with the keyboard up the sheet gets
            // far less height than the screen, so a fixed 46% cap overflows.
            // The cap keeps the list from swallowing a tall screen; the
            // Flexible lets it shrink to whatever the sheet actually has.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                ),
                child: _buildResults(hasQuery),
              ),
            ),
            if (_refining) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.addressSearchRefining,
                    style: AppTextStyles.mutedSm,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool hasQuery) {
    // Before a letter is typed: the places this driver actually goes. A
    // search box that opens empty asks the driver to remember an address
    // they have already told the app twice this week.
    if (!hasQuery) {
      if (_recents.isEmpty) {
        return _Hint(
          icon: Iconsax.location,
          message: AppStrings.addressSearchPrompt,
        );
      }
      return _ResultList(
        header: AppStrings.addressSearchRecents,
        results: _recents,
        onPick: _pick,
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_results.isEmpty) {
      return _Hint(
        icon: Iconsax.search_status,
        message: AppStrings.addressSearchEmpty,
      );
    }
    return _ResultList(results: _results, onPick: _pick);
  }
}

class _ResultList extends StatelessWidget {
  final String? header;
  final List<PlaceSuggestion> results;
  final void Function(PlaceSuggestion) onPick;

  const _ResultList({required this.results, required this.onPick, this.header});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: results.length + (header == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (header != null) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 4, left: 4),
              child: Text(header!, style: AppTextStyles.mutedSm),
            );
          }
          i -= 1;
        }
        final result = results[i];
        return _ResultTile(result: result, onTap: () => onPick(result));
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final PlaceSuggestion result;
  final VoidCallback onTap;
  const _ResultTile({required this.result, required this.onTap});

  /// One glance should say what kind of thing this is — a street, a town,
  /// a shop, or somewhere the driver has already been.
  IconData get _icon {
    if (result.source == PlaceSource.recent) return Iconsax.clock;
    if (result.source == PlaceSource.routePoint) return Iconsax.routing;
    return switch (result.kind) {
      PlaceKind.coordinate => Iconsax.gps,
      PlaceKind.street => Iconsax.routing_2,
      PlaceKind.city => Iconsax.buildings_2,
      PlaceKind.region => Iconsax.global,
      PlaceKind.area => Iconsax.buildings,
      PlaceKind.address => Iconsax.house,
      PlaceKind.poi => Iconsax.location,
    };
  }

  @override
  Widget build(BuildContext context) {
    final context_ = result.context?.trim();
    final distance = result.distanceKm;

    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.name,
                      style: AppTextStyles.bodyMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (context_ != null && context_.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        context_,
                        style: AppTextStyles.mutedSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // How far it is, right where the eye lands after the name.
              // This is the number that makes a ranked list checkable: the
              // driver can see at a glance that the top result really is
              // the near one.
              if (distance != null) ...[
                const SizedBox(width: 8),
                Text(
                  MetricFormat.distance(distance),
                  style: AppTextStyles.mutedSm,
                ),
              ],
              const SizedBox(width: 8),
              Icon(Iconsax.add_circle, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Hint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      // Full width, or the Column shrinks to its content and the sheet's
      // `CrossAxisAlignment.start` parks the whole block against the leading
      // edge — the right-hand side in Arabic. Centring inside a block that
      // is itself pushed to one side centres nothing.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
