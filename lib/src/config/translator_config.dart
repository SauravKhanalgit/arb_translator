import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Configuration settings for the ARB translator.
///
/// This class manages all configurable aspects of the translation process,
/// including API settings, rate limiting, and output preferences.
class TranslatorConfig {
  /// Creates a [TranslatorConfig] with the specified settings.
  const TranslatorConfig({
    this.maxConcurrentTranslations = 5,
    this.retryAttempts = 3,
    this.retryDelayMs = 1000,
    this.requestTimeoutMs = 30000,
    this.rateLimitDelayMs = 100,
    this.preserveMetadata = true,
    this.prettyPrintJson = true,
    this.backupOriginal = false,
    this.validateOutput = true,
    this.logLevel = LogLevel.info,
    this.customApiEndpoint,
    this.sourceLanguage = 'auto',
  });

  /// Maximum number of concurrent translation requests.
  final int maxConcurrentTranslations;

  /// Number of retry attempts for failed requests.
  final int retryAttempts;

  /// Delay between retry attempts in milliseconds.
  final int retryDelayMs;

  /// Request timeout in milliseconds.
  final int requestTimeoutMs;

  /// Delay between requests to avoid rate limiting in milliseconds.
  final int rateLimitDelayMs;

  /// Whether to preserve ARB metadata entries starting with '@'.
  final bool preserveMetadata;

  /// Whether to format output JSON with indentation.
  final bool prettyPrintJson;

  /// Whether to create backup files before overwriting.
  final bool backupOriginal;

  /// Whether to validate output ARB files after generation.
  final bool validateOutput;

  /// Logging level for console output.
  final LogLevel logLevel;

  /// Custom API endpoint URL (null for default Google Translate).
  final String? customApiEndpoint;

  /// Source language code for translation (default: 'auto' for auto-detect).
  final String sourceLanguage;

  /// Creates a [TranslatorConfig] from a YAML configuration file.
  ///
  /// If the file doesn't exist, returns a default configuration.
  static Future<TranslatorConfig> fromFile([String? configPath]) async {
    configPath ??= _getDefaultConfigPath();

    final file = File(configPath);
    if (!await file.exists()) {
      return const TranslatorConfig();
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as Map;

      return TranslatorConfig(
        maxConcurrentTranslations:
            yaml['maxConcurrentTranslations'] as int? ?? 5,
        retryAttempts: yaml['retryAttempts'] as int? ?? 3,
        retryDelayMs: yaml['retryDelayMs'] as int? ?? 1000,
        requestTimeoutMs: yaml['requestTimeoutMs'] as int? ?? 30000,
        rateLimitDelayMs: yaml['rateLimitDelayMs'] as int? ?? 100,
        preserveMetadata: yaml['preserveMetadata'] as bool? ?? true,
        prettyPrintJson: yaml['prettyPrintJson'] as bool? ?? true,
        backupOriginal: yaml['backupOriginal'] as bool? ?? false,
        validateOutput: yaml['validateOutput'] as bool? ?? true,
        logLevel: _parseLogLevel(yaml['logLevel'] as String? ?? 'info'),
        customApiEndpoint: yaml['customApiEndpoint'] as String?,
        sourceLanguage: yaml['sourceLanguage'] as String? ?? 'auto',
      );
    } catch (e) {
      throw ConfigurationException(
        'Failed to parse configuration file: $configPath',
        e.toString(),
      );
    }
  }

  /// Saves the current configuration to a YAML file.
  Future<void> saveToFile([String? configPath]) async {
    configPath ??= _getDefaultConfigPath();

    final configYaml = '''
# ARB Translator Configuration
# Generated on ${DateTime.now().toIso8601String()}

# Translation settings
maxConcurrentTranslations: $maxConcurrentTranslations
retryAttempts: $retryAttempts
retryDelayMs: $retryDelayMs
requestTimeoutMs: $requestTimeoutMs
rateLimitDelayMs: $rateLimitDelayMs
sourceLanguage: "$sourceLanguage"

# Output settings
preserveMetadata: $preserveMetadata
prettyPrintJson: $prettyPrintJson
backupOriginal: $backupOriginal
validateOutput: $validateOutput

# Logging
logLevel: "${logLevel.name}"

# API settings (optional)
${customApiEndpoint != null ? 'customApiEndpoint: "$customApiEndpoint"' : '# customApiEndpoint: "https://custom-api.example.com"'}
''';

    final file = File(configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(configYaml);
  }

  /// Creates a copy of this config with the specified changes.
  TranslatorConfig copyWith({
    int? maxConcurrentTranslations,
    int? retryAttempts,
    int? retryDelayMs,
    int? requestTimeoutMs,
    int? rateLimitDelayMs,
    bool? preserveMetadata,
    bool? prettyPrintJson,
    bool? backupOriginal,
    bool? validateOutput,
    LogLevel? logLevel,
    String? customApiEndpoint,
    String? sourceLanguage,
  }) {
    return TranslatorConfig(
      maxConcurrentTranslations:
          maxConcurrentTranslations ?? this.maxConcurrentTranslations,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelayMs: retryDelayMs ?? this.retryDelayMs,
      requestTimeoutMs: requestTimeoutMs ?? this.requestTimeoutMs,
      rateLimitDelayMs: rateLimitDelayMs ?? this.rateLimitDelayMs,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      prettyPrintJson: prettyPrintJson ?? this.prettyPrintJson,
      backupOriginal: backupOriginal ?? this.backupOriginal,
      validateOutput: validateOutput ?? this.validateOutput,
      logLevel: logLevel ?? this.logLevel,
      customApiEndpoint: customApiEndpoint ?? this.customApiEndpoint,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    );
  }

  static String _getDefaultConfigPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return path.join(home, '.arb_translator', 'config.yaml');
  }

  static LogLevel _parseLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// Logging levels for console output.
enum LogLevel {
  /// Debug level - most verbose.
  debug('DEBUG'),

  /// Info level - general information.
  info('INFO'),

  /// Warning level - potential issues.
  warning('WARNING'),

  /// Error level - only errors.
  error('ERROR');

  const LogLevel(this.name);

  /// Display name for the log level.
  final String name;
}

/// Exception thrown when configuration parsing fails.
class ConfigurationException implements Exception {
  /// Creates a [ConfigurationException] with the given [message] and [details].
  const ConfigurationException(this.message, this.details);

  /// Primary error message.
  final String message;

  /// Additional error details.
  final String details;

  @override
  String toString() => 'ConfigurationException: $message\nDetails: $details';
}
