import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/saved_route.dart';
import '../../domain/repositories/saved_routes_repository.dart';
import 'saved_routes_state.dart';

class SavedRoutesCubit extends Cubit<SavedRoutesState> {
  final SavedRoutesRepository _repo;

  SavedRoutesCubit(this._repo) : super(const SavedRoutesState());

  Future<void> load() async {
    emit(state.copyWith(status: SavedRoutesStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(
        status: SavedRoutesStatus.ready,
        routes: list,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SavedRoutesStatus.failure,
        errorMessage: 'تعذر تحميل المسارات المحفوظة',
      ));
    }
  }

  Future<SavedRoute?> save(SavedRoute route) async {
    emit(state.copyWith(status: SavedRoutesStatus.mutating, clearError: true));
    try {
      final saved = await _repo.upsert(route);
      final list = await _repo.list();
      emit(state.copyWith(
        status: SavedRoutesStatus.ready,
        routes: list,
      ));
      return saved;
    } catch (e) {
      emit(state.copyWith(
        status: SavedRoutesStatus.failure,
        errorMessage: 'تعذر حفظ المسار',
      ));
      return null;
    }
  }

  Future<void> rename(String id, String newName) async {
    if (newName.trim().isEmpty) return;
    emit(state.copyWith(pendingId: id));
    final ok = await _repo.rename(id, newName);
    if (ok) {
      final list = await _repo.list();
      emit(state.copyWith(
        routes: list,
        clearPending: true,
        status: SavedRoutesStatus.ready,
      ));
    } else {
      emit(state.copyWith(clearPending: true));
    }
  }

  Future<void> delete(String id) async {
    emit(state.copyWith(pendingId: id));
    await _repo.delete(id);
    final list = await _repo.list();
    emit(state.copyWith(
      routes: list,
      clearPending: true,
      status: SavedRoutesStatus.ready,
    ));
  }

  Future<void> clearAll() async {
    emit(state.copyWith(status: SavedRoutesStatus.mutating));
    await _repo.clearAll();
    emit(state.copyWith(
      status: SavedRoutesStatus.ready,
      routes: const [],
    ));
  }
}
