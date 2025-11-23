/// Result type for repository operations
/// Inspired by Kotlin's Result and Rust's Result
import '../localization/app_error_key.dart';
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

// ----------------- failures.dart (Updated) -----------------

// Assuming AppErrorKey is defined elsewhere

/// Base class for all failures.
sealed class Failure {
  final String message; // Technical message for logging/debugging
  final Exception? exception;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.exception, this.stackTrace});

  @override
  String toString() => message;
}

// -------------------------------------------------------------
// TECHNICAL FAILURES (Used by Repository - No localization keys)
// -------------------------------------------------------------

/// Database operation failure
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.exception, super.stackTrace});
}

/// Generic technical failure
class GenericFailure extends Failure {
  const GenericFailure(super.message, {super.exception, super.stackTrace});
}


// -------------------------------------------------------------
// LOCALIZED FAILURES (Used by Service/Provider - Carries AppErrorKey)
// -------------------------------------------------------------

/// Sealed base class for failures that require localized messages for the UI.
sealed class LocalizedFailure extends Failure {
  final AppErrorKey errorKey;
  final Map<String, dynamic>? params;

  // Localized failures use a generic technical message ('Business Rule Violated')
  // and rely on errorKey for the UI.
  const LocalizedFailure(
    this.errorKey, {
    this.params,
    String message = 'Business Rule Violation',
  }) : super(message);
}

/// Validation failure
class ValidationFailure extends LocalizedFailure {
  const ValidationFailure(super.errorKey, {super.params, super.message = 'Input Validation Failed'});
}

/// Not found failure (e.g., trying to operate on a non-existent item)
class NotFoundFailure extends LocalizedFailure {
  const NotFoundFailure(super.errorKey, {super.params, super.message = 'Entity Not Found'});
}

/// Duplicate failure (e.g., trying to create a duplicate name)
class DuplicateFailure extends LocalizedFailure {
  const DuplicateFailure(super.errorKey, {super.params, super.message = 'Duplicate Entity Found'});
}

/// Business rule violation failure (e.g., cannot delete family with items)
class BusinessRuleFailure extends LocalizedFailure {
  const BusinessRuleFailure(super.errorKey, {super.params, super.message = 'Business Logic Constraint'});
}