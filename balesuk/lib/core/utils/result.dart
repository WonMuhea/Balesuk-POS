/// Result type for repository operations
/// Inspired by Kotlin's Result and Rust's Result
sealed class Result<T> {
  const Result();

  /// Execute different code paths based on success/failure
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return error((this as Error<T>).failure);
    }
  }

  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is error
  bool get isError => this is Error<T>;

  /// Get data or null
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;

  /// Get failure or null
  Failure? get failureOrNull => this is Error<T> ? (this as Error<T>).failure : null;
}

/// Success result with data
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  String toString() => 'Success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Error result with failure
class Error<T> extends Result<T> {
  final Failure failure;

  const Error(this.failure);

  @override
  String toString() => 'Error($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error && runtimeType == other.runtimeType && failure == other.failure;

  @override
  int get hashCode => failure.hashCode;
}

/// Failure types
sealed class Failure {
  final String message;
  final Exception? exception;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.exception, this.stackTrace});

  @override
  String toString() => message;
}

/// Database operation failure
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.exception, super.stackTrace});
}

/// Validation failure
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Duplicate failure
class DuplicateFailure extends Failure {
  const DuplicateFailure(super.message);
}

/// Business rule violation failure
class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure(super.message);
}

/// Generic failure
class GenericFailure extends Failure {
  const GenericFailure(super.message, {super.exception, super.stackTrace});
}