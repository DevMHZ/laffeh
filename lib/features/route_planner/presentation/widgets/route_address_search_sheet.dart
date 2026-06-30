import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/datasources/osm_geocoding_datasource.dart';
import '../cubit/route_planner_cubit.dart';

/// Single-address search: type a query, pick one match from the list, and the
/// chosen place is added as the next point. One address at a time — there is
/// deliberately no bulk/list paste here.
Future<void> showAddressSearchSheet(
  BuildContext context,
  RoutePlannerCubit cubit,
) {
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
      child: _AddressSearchBody(cubit: cubit),
    ),
  );
}

class _AddressSearchBody extends StatefulWidget {
  final RoutePlannerCubit cubit;
  const _AddressSearchBody({required this.cubit});

  @override
  State<_AddressSearchBody> createState() => _AddressSearchBodyState();
}

class _AddressSearchBodyState extends State<_AddressSearchBody> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Monotonic token so a slow request can't overwrite a newer one's results.
  int _queryToken = 0;
  bool _loading = false;
  List<GeoSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _results = const [];
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_queryToken;
    final results = await widget.cubit.searchAddresses(query);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _loading = false;
      _results = results;
    });
  }

  void _pick(GeoSearchResult result) {
    HapticFeedback.selectionClick();
    widget.cubit.addPoint(result.latLng, address: result.name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.addressSearchTitle, style: AppTextStyles.h3),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                final q = v.trim();
                if (q.isNotEmpty) _search(q);
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: _buildResults(hasQuery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool hasQuery) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasQuery) {
      return _Hint(
        icon: Iconsax.location,
        message: AppStrings.addressSearchPrompt,
      );
    }
    if (_results.isEmpty) {
      return _Hint(
        icon: Iconsax.search_status,
        message: AppStrings.addressSearchEmpty,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ResultTile(
        result: _results[i],
        onTap: () => _pick(_results[i]),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final GeoSearchResult result;
  final VoidCallback onTap;
  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(
                  Iconsax.location,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  result.name,
                  style: AppTextStyles.bodyMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Iconsax.add_circle,
                size: 20,
                color: AppColors.primary,
              ),
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
    );
  }
}
