import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A non-blocking explanation of what still works without internet. Kept
/// independent of the map and cubit so the same copy and retry affordance
/// can live in both planning and driving layouts.
class RouteConnectivityNotice extends StatefulWidget {
  const RouteConnectivityNotice({
    super.key,
    required this.hasSavedRoute,
    required this.onRetry,
    this.isDriving = false,
  });

  final bool hasSavedRoute;
  final bool isDriving;
  final Future<void> Function() onRetry;

  @override
  State<RouteConnectivityNotice> createState() =>
      _RouteConnectivityNoticeState();
}

class _RouteConnectivityNoticeState extends State<RouteConnectivityNotice> {
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivingSavedRoute = widget.isDriving && widget.hasSavedRoute;
    final title = drivingSavedRoute
        ? AppStrings.offlineDriveTitle
        : AppStrings.offlineTitle;
    final body = drivingSavedRoute
        ? AppStrings.offlineDriveBody
        : widget.hasSavedRoute
        ? AppStrings.offlineSavedRouteBody
        : AppStrings.offlineBody;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.titleSm),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: _checking
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                            semanticsLabel: AppStrings.checkingConnection,
                          ),
                        )
                      : IconButton(
                          tooltip: AppStrings.checkConnection,
                          onPressed: _retry,
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: AppColors.primary,
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
