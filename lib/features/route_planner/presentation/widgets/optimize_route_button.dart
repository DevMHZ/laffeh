import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';

class OptimizeRouteButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  const OptimizeRouteButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: AppStrings.optimizeRoute,
      icon: Iconsax.routing_2,
      loading: loading,
      onPressed: (enabled && !loading) ? onPressed : null,
    );
  }
}
