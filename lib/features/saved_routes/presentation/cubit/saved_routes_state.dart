import 'package:equatable/equatable.dart';

import '../../domain/entities/saved_route.dart';

enum SavedRoutesStatus { initial, loading, ready, mutating, failure }

class SavedRoutesState extends Equatable {
  final SavedRoutesStatus status;
  final List<SavedRoute> routes;
  final String? errorMessage;

  /// Tracks which row is currently being renamed/deleted so the tile
  /// can show a spinner without freezing the whole list.
  final String? pendingId;

  const SavedRoutesState({
    this.status = SavedRoutesStatus.initial,
    this.routes = const [],
    this.errorMessage,
    this.pendingId,
  });

  bool get isLoading => status == SavedRoutesStatus.loading;
  bool get isReady => status == SavedRoutesStatus.ready;
  bool get isEmpty => routes.isEmpty && isReady;

  SavedRoutesState copyWith({
    SavedRoutesStatus? status,
    List<SavedRoute>? routes,
    String? errorMessage,
    String? pendingId,
    bool clearError = false,
    bool clearPending = false,
  }) =>
      SavedRoutesState(
        status: status ?? this.status,
        routes: routes ?? this.routes,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pendingId: clearPending ? null : (pendingId ?? this.pendingId),
      );

  @override
  List<Object?> get props => [status, routes, errorMessage, pendingId];
}
