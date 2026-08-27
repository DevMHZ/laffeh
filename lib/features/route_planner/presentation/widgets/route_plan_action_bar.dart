import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'optimize_route_button.dart';

/// The planner's one primary action, pinned to the foot of the sheet.
///
/// Optimizing is the entire point of the app, and it used to sit at the end
/// of a scrolling column inside a sheet that opens collapsed. With the sheet
/// peeking, the only button on screen was "add a stop"; the one that matters
/// was a drag and a scroll away, and drivers reported not finding it at all.
///
/// So it leaves the scroll. Anchored here it is visible at every drag
/// position, it never moves as stops are added, and it sits where a thumb
/// already rests. The readiness line above it is the same one that used to
/// live in the list — kept, because a disabled button with no reason beside
/// it is the other way to lose someone.
class RoutePlanActionBar extends StatelessWidget {
  /// Points that will actually be routed — deactivated optional stops
  /// excluded, which is what "ready" has to be counted from.
  final int pointsCount;

  final bool canOptimize;
  final bool isOptimizing;
  final VoidCallback onOptimize;

  const RoutePlanActionBar({
    super.key,
    required this.pointsCount,
    required this.canOptimize,
    required this.isOptimizing,
    required this.onOptimize,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final ready = pointsCount >= 2;

    // Not being finished yet is the normal state of a plan being made, so
    // the button says what is still missing rather than sitting there greyed
    // out with a warning line over it. One control, one message, one row.
    final label = ready
        ? AppStrings.optimizeRoute
        : pointsCount == 0
        ? AppStrings.setDepartureFirst
        : AppStrings.addOneStopToOptimize;

    return DecoratedBox(
      // Only a hairline: the bar shares the sheet's surface, so anything
      // heavier would read as a second sheet stacked on the first.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + safeBottom),
        child: OptimizeRouteButton(
          enabled: canOptimize,
          loading: isOptimizing,
          label: label,
          onPressed: onOptimize,
        ),
      ),
    );
  }
}
