import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// A selectable "reason for using the app". [code] mirrors the seeded
/// `use_cases.code`; the `save_onboarding` RPC resolves codes → ids
/// server-side, so the client never needs to fetch the catalogue to submit.
///
/// [label] is a getter reference (not a captured string) so it re-resolves in
/// the active language every time it's read.
class UseCaseOption {
  final String code;
  final IconData icon;
  final String Function() label;

  const UseCaseOption({
    required this.code,
    required this.icon,
    required this.label,
  });

  static const String otherCode = 'other';

  bool get isOther => code == otherCode;

  static final List<UseCaseOption> all = <UseCaseOption>[
    UseCaseOption(
      code: 'delivery',
      icon: Icons.inventory_2_outlined,
      label: () => AppStrings.ucDelivery,
    ),
    UseCaseOption(
      code: 'personal_use',
      icon: Icons.person_outline,
      label: () => AppStrings.ucPersonalUse,
    ),
    UseCaseOption(
      code: 'navigation',
      icon: Icons.explore_outlined,
      label: () => AppStrings.ucNavigation,
    ),
    UseCaseOption(
      code: 'driver',
      icon: Icons.drive_eta_outlined,
      label: () => AppStrings.ucDriver,
    ),
    UseCaseOption(
      code: 'delivery_driver',
      icon: Icons.two_wheeler_outlined,
      label: () => AppStrings.ucDeliveryDriver,
    ),
    UseCaseOption(
      code: 'fleet_management',
      icon: Icons.local_shipping_outlined,
      label: () => AppStrings.ucFleetManagement,
    ),
    UseCaseOption(
      code: 'business_management',
      icon: Icons.business_center_outlined,
      label: () => AppStrings.ucBusinessManagement,
    ),
    UseCaseOption(
      code: 'route_planning',
      icon: Icons.alt_route_outlined,
      label: () => AppStrings.ucRoutePlanning,
    ),
    UseCaseOption(
      code: 'field_operations',
      icon: Icons.radar_outlined,
      label: () => AppStrings.ucFieldOperations,
    ),
    UseCaseOption(
      code: 'field_sales',
      icon: Icons.trending_up_outlined,
      label: () => AppStrings.ucFieldSales,
    ),
    UseCaseOption(
      code: otherCode,
      icon: Icons.more_horiz,
      label: () => AppStrings.ucOther,
    ),
  ];

  /// Resolves a code back to its localized label (used by the summary screen).
  static String labelForCode(String code) {
    for (final o in all) {
      if (o.code == code) return o.label();
    }
    return code;
  }
}
