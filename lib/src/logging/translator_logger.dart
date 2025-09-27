import 'dart:io';

import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:logging/logging.dart';

/// A centralized logging service for the ARB translator.
///
/// This class provides structured logging with different levels and formats,
/// supporting both console and file output.
class TranslatorLogger {
  /// Gets the singleton instance of [TranslatorLogger].
  factory TranslatorLogger() => _instance;
  TranslatorLogger._internal();

  static final TranslatorLogger _instance = TranslatorLogger._internal();

  late Logger _logger;
  late LogLevel _currentLevel;
  bool _initialized = false;

  /// Initializes the logger with the given configuration.
  void initialize(LogLevel level) {
    if (_initialized) return;

    _currentLevel = level;
    _logger = Logger('ArbTranslator');

    // Set the logging level
    Logger.root.level = _mapLogLevel(level);

    // Configure the console output handler
    Logger.root.onRecord.listen((record) {
      if (_shouldLog(record.level)) {
        _printWithColor(record);
      }
    });

    _initialized = true;
  }

  /// Logs a debug message.
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine(message, error, stackTrace);
  }

  /// Logs an info message.
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  /// Logs a warning message.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  /// Logs a success message (info level with green color).
  void success(String message) {
    _logger.info('✅ $message');
  }

  /// Logs a progress message (info level with blue color).
  void progress(String message) {
    _logger.info('🔄 $message');
  }

  /// Logs a completion message (info level with checkmark).
  void complete(String message) {
    _logger.info('✅ $message');
  }

  Level _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Level.FINE;
      case LogLevel.info:
        return Level.INFO;
      case LogLevel.warning:
        return Level.WARNING;
      case LogLevel.error:
        return Level.SEVERE;
    }
  }

  bool _shouldLog(Level level) {
    return level.value >= _mapLogLevel(_currentLevel).value;
  }

  void _printWithColor(LogRecord record) {
    final timestamp = _formatTimestamp(record.time);
    final level = record.level.name.padRight(7);
    final message = record.message;

    String colorCode;
    const resetCode = '\x1b[0m';

    // Choose color based on log level
    switch (record.level) {
      case Level.SEVERE:
        colorCode = '\x1b[31m'; // Red
      case Level.WARNING:
        colorCode = '\x1b[33m'; // Yellow
      case Level.INFO:
        if (message.startsWith('✅')) {
          colorCode = '\x1b[32m'; // Green for success
        } else if (message.startsWith('🔄')) {
          colorCode = '\x1b[36m'; // Cyan for progress
        } else {
          colorCode = '\x1b[37m'; // White
        }
      case Level.FINE:
        colorCode = '\x1b[90m'; // Gray
      default:
        colorCode = '\x1b[37m'; // White
    }

    // Print with color if terminal supports it
    if (_supportsAnsiColors()) {
      print('$colorCode[$timestamp] $level $message$resetCode');
    } else {
      print('[$timestamp] $level $message');
    }

    // Print error details if present
    if (record.error != null) {
      final errorColor = _supportsAnsiColors() ? '\x1b[31m' : '';
      print('$errorColor  Error: ${record.error}$resetCode');
    }

    // Print stack trace if present and debug level
    if (record.stackTrace != null && _currentLevel == LogLevel.debug) {
      final stackColor = _supportsAnsiColors() ? '\x1b[90m' : '';
      print('$stackColor  Stack: ${record.stackTrace}$resetCode');
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  bool _supportsAnsiColors() {
    return Platform.isLinux ||
        Platform.isMacOS ||
        (Platform.isWindows && _isWindowsTerminalWithAnsiSupport());
  }

  bool _isWindowsTerminalWithAnsiSupport() {
    // Check if running in modern Windows Terminal or PowerShell
    final term = Platform.environment['TERM'];
    final wtSession = Platform.environment['WT_SESSION'];
    return term != null || wtSession != null;
  }
}

/// Extension methods for easier logging.
extension LoggerExtensions on Object {
  /// Logs this object as a debug message.
  void logDebug([String? prefix]) {
    final message = prefix != null ? '$prefix: $toString()' : toString();
    TranslatorLogger().debug(message);
  }

  /// Logs this object as an info message.
  void logInfo([String? prefix]) {
    final message = prefix != null ? '$prefix: $toString()' : toString();
    TranslatorLogger().info(message);
  }

  /// Logs this object as a warning message.
  void logWarning([String? prefix]) {
    final message = prefix != null ? '$prefix: $toString()' : toString();
    TranslatorLogger().warning(message);
  }

  /// Logs this object as an error message.
  void logError([String? prefix]) {
    final message = prefix != null ? '$prefix: $toString()' : toString();
    TranslatorLogger().error(message);
  }
}
