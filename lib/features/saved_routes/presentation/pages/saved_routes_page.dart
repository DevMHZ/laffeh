import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/saved_route.dart';
import '../cubit/saved_routes_cubit.dart';
import '../cubit/saved_routes_state.dart';
import '../widgets/saved_route_card.dart';

/// Route history page. Returns the selected [SavedRoute] via
/// Navigator.pop when the user taps "open", so the planner can
/// reload it.
class SavedRoutesPage extends StatelessWidget {
  const SavedRoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedRoutesCubit>(
      create: (_) => sl<SavedRoutesCubit>()..load(),
      child: const _SavedRoutesView(),
    );
  }
}

class _SavedRoutesView extends StatelessWidget {
  const _SavedRoutesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.savedRoutes),
        actions: [
          BlocBuilder<SavedRoutesCubit, SavedRoutesState>(
            buildWhen: (a, b) => a.routes.length != b.routes.length,
            builder: (context, state) {
              if (state.routes.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: AppStrings.clearAll,
                icon: const Icon(Iconsax.trash, color: AppColors.danger),
                onPressed: () => _confirmClearAll(context),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SavedRoutesCubit, SavedRoutesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: AppLoading());
          }
          if (state.status == SavedRoutesStatus.failure) {
            return AppErrorView(
              message: state.errorMessage ?? 'حدث خطأ',
              onRetry: () => context.read<SavedRoutesCubit>().load(),
            );
          }
          if (state.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: AppEmptyView(
                  icon: Iconsax.archive_book,
                  message: '${AppStrings.savedRoutesEmpty}\n\n',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            itemCount: state.routes.length,
            itemBuilder: (ctx, i) {
              final r = state.routes[i];
              final busy = state.pendingId == r.id;
              return SavedRouteCard(
                route: r,
                busy: busy,
                onOpen: () => Navigator.of(context).pop<SavedRoute>(r),
                onRename: () => _renameDialog(context, r),
                onDelete: () => _deleteDialog(context, r),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, SavedRoute r) async {
    final cubit = context.read<SavedRoutesCubit>();
    final newName = await AppDialog.input(
      context: context,
      title: AppStrings.renameRouteTitle,
      message: AppStrings.saveRouteHint,
      hint: AppStrings.defaultRouteName,
      initialValue: r.name,
      icon: Iconsax.edit,
      tone: AppDialogTone.primary,
    );
    if (newName != null && newName.isNotEmpty) {
      await cubit.rename(r.id, newName);
    }
  }

  Future<void> _deleteDialog(BuildContext context, SavedRoute r) async {
    final cubit = context.read<SavedRoutesCubit>();
    final ok = await AppDialog.confirm(
      context: context,
      title: AppStrings.deleteRouteTitle,
      message: '${AppStrings.deleteRouteConfirm}\n\n«${r.name}»',
      confirmLabel: AppStrings.remove,
      confirmIcon: Iconsax.trash,
      icon: Iconsax.warning_2,
      tone: AppDialogTone.danger,
      destructive: true,
    );
    if (ok == true) {
      await cubit.delete(r.id);
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final cubit = context.read<SavedRoutesCubit>();
    final ok = await AppDialog.confirm(
      context: context,
      title: AppStrings.clearAll,
      message: 'سيتم حذف كل المسارات المحفوظة. هل أنت متأكد؟',
      confirmLabel: AppStrings.clearAll,
      confirmIcon: Iconsax.trash,
      icon: Iconsax.warning_2,
      tone: AppDialogTone.danger,
      destructive: true,
    );
    if (ok == true) await cubit.clearAll();
  }
}

/// Branded save dialog reused by the planner.
Future<String?> showSaveRouteDialog(
  BuildContext context, {
  required String initialName,
}) {
  return AppDialog.input(
    context: context,
    title: AppStrings.saveRouteTitle,
    message: AppStrings.saveRouteHint,
    hint: AppStrings.defaultRouteName,
    initialValue: initialName,
    icon: Iconsax.save_2,
    tone: AppDialogTone.success,
  );
}

/// Three-option dialog: save current, discard, or cancel.
/// Returns one of [SaveBeforeClearChoice] (or null on cancel).
Future<SaveBeforeClearChoice?> showSaveBeforeClearDialog(BuildContext context) {
  return AppDialog.show<SaveBeforeClearChoice>(
    context: context,
    title: AppStrings.saveRouteTitle,
    message: AppStrings.askKeepCurrentRoute,
    icon: Iconsax.save_2,
    tone: AppDialogTone.primary,
    actions: const [
      AppDialogAction(label: AppStrings.cancel, popWith: null),
      AppDialogAction(
        label: AppStrings.dontSave,
        popWith: SaveBeforeClearChoice.discard,
      ),
      AppDialogAction(
        label: AppStrings.saveAndContinue,
        icon: Iconsax.save_2,
        primary: true,
        popWith: SaveBeforeClearChoice.save,
      ),
    ],
  );
}

enum SaveBeforeClearChoice { save, discard }
