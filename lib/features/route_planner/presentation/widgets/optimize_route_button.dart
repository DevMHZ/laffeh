import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';

class OptimizeRouteButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  /// What the button says. A plan that cannot be optimized yet says what it
  /// is waiting for, right here, instead of on a line of its own above —
  /// that line spent a whole row of the sheet repeating what the button was
  /// already in a position to say.
  final String? label;

  const OptimizeRouteButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label ?? AppStrings.optimizeRoute,
      icon: enabled ? Iconsax.routing_2 : Iconsax.magicpen,
      loading: loading,
      onPressed: (enabled && !loading) ? onPressed : null,
    );
  }
}
