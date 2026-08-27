import 'package:flutter/widgets.dart';

/// Marks every element under [context] as needing a rebuild.
///
/// For state that lives outside the widget tree — the app's language
/// ([AppStrings]) and palette ([AppColors]) are plain statics, read at build
/// time by widgets that subscribe to nothing — a change has no way of
/// reaching the screens already built. Rebuilding the top of the app does not
/// help either: the Navigator hands its pages the same widget instances, so
/// Flutter correctly skips them, and the user goes on reading the old
/// language until the app is restarted.
///
/// Re-keying the app would fix that by destroying the tree, which is exactly
/// what must not happen here: the planner's native map surface would be torn
/// down and rebuilt with it. Marking the subtree dirty gets the rebuild
/// without the teardown — every [State], the map's included, survives.
///
/// Must not be called during a build; schedule it after the frame if the
/// change can arrive mid-build.
void markSubtreeForRebuild(BuildContext context) {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  (context as Element).visitChildren(mark);
}
