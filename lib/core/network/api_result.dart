import '../error/failures.dart';

/// Lightweight Result/Either type for repository methods.
///
/// Each public repository method returns `ApiResult<T>`. The UI
/// matches on [isSuccess] or destructures `success` / `failure`
/// instead of dealing with raw exceptions or `dynamic`.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull => this is ApiSuccess<T> ? (this as ApiSuccess<T>).data : null;
  Failure? get failureOrNull =>
      this is ApiFailure<T> ? (this as ApiFailure<T>).failure : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    if (this is ApiSuccess<T>) return success((this as ApiSuccess<T>).data);
    return failure((this as ApiFailure<T>).failure);
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final Failure failure;
  const ApiFailure(this.failure);
}
