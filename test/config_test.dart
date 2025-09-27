import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:test/test.dart';

void main() {
  group('TranslatorConfig Tests', () {
    test('should create config with default values', () {
      const config = TranslatorConfig();

      expect(config.maxConcurrentTranslations, equals(5));
      expect(config.retryAttempts, equals(3));
      expect(config.retryDelayMs, equals(1000));
      expect(config.requestTimeoutMs, equals(30000));
      expect(config.rateLimitDelayMs, equals(100));
      expect(config.preserveMetadata, isTrue);
      expect(config.prettyPrintJson, isTrue);
      expect(config.backupOriginal, isFalse);
      expect(config.validateOutput, isTrue);
      expect(config.logLevel, equals(LogLevel.info));
      expect(config.sourceLanguage, equals('auto'));
      expect(config.customApiEndpoint, isNull);
    });

    test('should create config with custom values', () {
      const config = TranslatorConfig(
        maxConcurrentTranslations: 10,
        retryAttempts: 5,
        logLevel: LogLevel.debug,
        customApiEndpoint: 'https://api.example.com',
      );

      expect(config.maxConcurrentTranslations, equals(10));
      expect(config.retryAttempts, equals(5));
      expect(config.logLevel, equals(LogLevel.debug));
      expect(config.customApiEndpoint, equals('https://api.example.com'));
    });

    test('should copy config with changes', () {
      const originalConfig = TranslatorConfig();

      final newConfig = originalConfig.copyWith(
        maxConcurrentTranslations: 8,
        logLevel: LogLevel.warning,
      );

      expect(newConfig.maxConcurrentTranslations, equals(8));
      expect(newConfig.logLevel, equals(LogLevel.warning));
      expect(newConfig.retryAttempts, equals(3)); // Should keep original value
    });

    test('should handle all log levels', () {
      expect(LogLevel.debug.name, equals('DEBUG'));
      expect(LogLevel.info.name, equals('INFO'));
      expect(LogLevel.warning.name, equals('WARNING'));
      expect(LogLevel.error.name, equals('ERROR'));
    });
  });
}
