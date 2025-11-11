import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging service for the application
/// Usage: AppLogger.info('Message'), AppLogger.error('Error', error, stackTrace)
class AppLogger {
  static const String _appName = 'Balesuk';
  
  // Enable/disable logging based on build mode
  static bool get _isEnabled => kDebugMode;

  // ==================== LOG LEVELS ====================

  /// Log informational messages
  /// Use for: General app flow, navigation, user actions
  static void info(String message, {String? tag}) {
    if (!_isEnabled) return;
    _log('ℹ️ INFO', message, tag: tag);
  }

  /// Log debug messages
  /// Use for: Development debugging, detailed flow tracking
  static void debug(String message, {String? tag}) {
    if (!_isEnabled) return;
    _log('🐛 DEBUG', message, tag: tag);
  }

  /// Log warnings
  /// Use for: Potential issues, deprecated usage, recoverable errors
  static void warning(String message, {String? tag}) {
    if (!_isEnabled) return;
    _log('⚠️ WARNING', message, tag: tag);
  }

  /// Log errors with optional error object and stack trace
  /// Use for: Caught exceptions, validation failures
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_isEnabled) return;
    _log('❌ ERROR', message, tag: tag);
    if (error != null) {
      developer.log(
        'Error Object: $error',
        name: '$_appName${tag != null ? ':$tag' : ''}',
        level: 1000,
      );
    }
    if (stackTrace != null) {
      developer.log(
        'Stack Trace:\n$stackTrace',
        name: '$_appName${tag != null ? ':$tag' : ''}',
        level: 1000,
      );
    }
  }

  /// Log critical errors that require immediate attention
  /// Use for: Fatal errors, data corruption, system failures
  static void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    // Critical errors are always logged, even in release mode
    _log('🚨 CRITICAL', message, tag: tag, alwaysLog: true);
    if (error != null) {
      developer.log(
        'Error Object: $error',
        name: '$_appName${tag != null ? ':$tag' : ''}',
        level: 2000,
      );
    }
    if (stackTrace != null) {
      developer.log(
        'Stack Trace:\n$stackTrace',
        name: '$_appName${tag != null ? ':$tag' : ''}',
        level: 2000,
      );
    }
  }

  /// Log success messages
  /// Use for: Completed operations, successful saves/syncs
  static void success(String message, {String? tag}) {
    if (!_isEnabled) return;
    _log('✅ SUCCESS', message, tag: tag);
  }

  // ==================== SPECIALIZED LOGGERS ====================

  /// Log database operations
  static void database(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('💾 DATABASE', '$operation${details != null ? ' - $details' : ''}', tag: 'DB');
  }

  /// Log network/sync operations
  static void network(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('🌐 NETWORK', '$operation${details != null ? ' - $details' : ''}', tag: 'NET');
  }

  /// Log navigation events
  static void navigation(String route, {String? details}) {
    if (!_isEnabled) return;
    _log('🧭 NAVIGATION', 'Route: $route${details != null ? ' - $details' : ''}', tag: 'NAV');
  }

  /// Log business logic operations
  static void business(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('💼 BUSINESS', '$operation${details != null ? ' - $details' : ''}', tag: 'BIZ');
  }

  /// Log authentication/authorization events
  static void auth(String event, {String? details}) {
    if (!_isEnabled) return;
    _log('🔐 AUTH', '$event${details != null ? ' - $details' : ''}', tag: 'AUTH');
  }

  /// Log sync operations
  static void sync(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('🔄 SYNC', '$operation${details != null ? ' - $details' : ''}', tag: 'SYNC');
  }

  /// Log transaction operations
  static void transaction(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('💳 TRANSACTION', '$operation${details != null ? ' - $details' : ''}', tag: 'TXN');
  }

  /// Log inventory operations
  static void inventory(String operation, {String? details}) {
    if (!_isEnabled) return;
    _log('📦 INVENTORY', '$operation${details != null ? ' - $details' : ''}', tag: 'INV');
  }

  // ==================== PERFORMANCE LOGGING ====================

  /// Log performance metrics
  static void performance(String operation, Duration duration) {
    if (!_isEnabled) return;
    _log('⚡ PERFORMANCE', '$operation took ${duration.inMilliseconds}ms', tag: 'PERF');
  }

  /// Measure and log execution time of a function
  static Future<T> measure<T>(
    String operation,
    Future<T> Function() function,
  ) async {
    if (!_isEnabled) {
      return await function();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      performance(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error(
        'Failed during $operation (${stopwatch.elapsed.inMilliseconds}ms)',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== PRIVATE HELPERS ====================

  static void _log(
    String level,
    String message, {
    String? tag,
    bool alwaysLog = false,
  }) {
    if (!_isEnabled && !alwaysLog) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    final tagStr = tag != null ? '[$tag]' : '';
    final fullMessage = '$timestamp $level $tagStr $message';

    developer.log(
      fullMessage,
      name: '$_appName${tag != null ? ':$tag' : ''}',
      time: DateTime.now(),
    );

    // Also print to console in debug mode for easier viewing
    if (kDebugMode) {
      debugPrint(fullMessage);
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Log a separator line for readability
  static void separator({String char = '=', int length = 50}) {
    if (!_isEnabled) return;
    _log('', char * length);
  }

  /// Log a section header
  static void section(String title) {
    if (!_isEnabled) return;
    separator();
    info('>>> $title <<<');
    separator();
  }

  /// Log object details (useful for debugging)
  static void object(String name, Object? object) {
    if (!_isEnabled) return;
    debug('$name: ${object.toString()}');
  }

  /// Log a map of key-value pairs
  static void map(String name, Map<String, dynamic> data) {
    if (!_isEnabled) return;
    debug('$name:');
    data.forEach((key, value) {
      debug('  $key: $value');
    });
  }
}

// ==================== LOGGER MIXIN ====================

/// Mixin to add logging capabilities to any class
mixin LoggerMixin {
  String get loggerTag => runtimeType.toString();

  void logInfo(String message) => AppLogger.info(message, tag: loggerTag);
  void logDebug(String message) => AppLogger.debug(message, tag: loggerTag);
  void logWarning(String message) => AppLogger.warning(message, tag: loggerTag);
  void logError(String message, {Object? error, StackTrace? stackTrace}) =>
      AppLogger.error(message, error: error, stackTrace: stackTrace, tag: loggerTag);
  void logSuccess(String message) => AppLogger.success(message, tag: loggerTag);
}