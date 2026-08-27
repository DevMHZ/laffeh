import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/saved_routes_sync_service.dart';
import '../../domain/entities/saved_route.dart';
import '../../domain/repositories/saved_routes_repository.dart';
import 'saved_routes_state.dart';

class SavedRoutesCubit extends Cubit<SavedRoutesState> {
  final SavedRoutesRepository _repo;
  final SavedRoutesSyncService? _sync;

  StreamSubscription<void>? _syncSub;

  SavedRoutesCubit(this._repo, [this._sync]) : super(const SavedRoutesState()) {
    // A sync started elsewhere (sign-in, app resume) can land while this page
    // is open; when it changes what is stored, show the new list.
    _syncSub = _sync?.changes.listen((_) => _refresh());
  }

  /// Reads the on-device history — instantly, and with no network — then asks
  /// the account for anything this phone hasn't seen. The list appears first
  /// and fills in afterwards, rather than the page waiting on a round trip.
  Future<void> load() async {
    emit(state.copyWith(status: SavedRoutesStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: SavedRoutesStatus.ready, routes: list));
    } catch (e) {
      emit(
        state.copyWith(
          status: SavedRoutesStatus.failure,
          errorMessage: AppStrings.errSavedRoutesLoad,
        ),
      );
      return;
    }
    unawaited(_sync?.syncNow());
  }

  /// Re-reads the local list without the loading state — the page is already
  /// showing something and a spinner would only make it flicker.
  Future<void> _refresh() async {
    if (isClosed) return;
    try {
      final list = await _repo.list();
      if (isClosed) return;
      emit(state.copyWith(status: SavedRoutesStatus.ready, routes: list));
    } catch (_) {
      // The list on screen is still valid; leave it alone.
    }
  }

  Future<SavedRoute?> save(SavedRoute route) async {
    emit(state.copyWith(status: SavedRoutesStatus.mutating, clearError: true));
    try {
      final saved = await _repo.upsert(route);
      final list = await _repo.list();
      emit(state.copyWith(status: SavedRoutesStatus.ready, routes: list));
      return saved;
    } catch (e) {
      emit(
        state.copyWith(
          status: SavedRoutesStatus.failure,
          errorMessage: AppStrings.errSavedRouteSave,
        ),
      );
      return null;
    }
  }

  Future<void> rename(String id, String newName) async {
    if (newName.trim().isEmpty) return;
    emit(state.copyWith(pendingId: id));
    final ok = await _repo.rename(id, newName);
    if (ok) {
      final list = await _repo.list();
      emit(
        state.copyWith(
          routes: list,
          clearPending: true,
          status: SavedRoutesStatus.ready,
        ),
      );
    } else {
      emit(state.copyWith(clearPending: true));
    }
  }

  Future<void> delete(String id) async {
    emit(state.copyWith(pendingId: id));
    await _repo.delete(id);
    final list = await _repo.list();
    emit(
      state.copyWith(
        routes: list,
        clearPending: true,
        status: SavedRoutesStatus.ready,
      ),
    );
  }

  Future<void> clearAll() async {
    emit(state.copyWith(status: SavedRoutesStatus.mutating));
    await _repo.clearAll();
    emit(state.copyWith(status: SavedRoutesStatus.ready, routes: const []));
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }
}
