/// Advanced API Usage Examples for ARB Translator Gen Z
///
/// This example demonstrates advanced features and patterns for
/// integrating ARB translation into your Dart applications.

import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  // Example 1: Error handling patterns
  await errorHandlingExample();

  // Example 2: Custom configuration management
  await configurationManagementExample();

  // Example 3: Translation service integration
  await translationServiceExample();

  // Example 4: Batch processing with progress tracking
  await batchProcessingExample();

  // Example 5: CI/CD integration pattern
  await cicdIntegrationExample();
}

/// Example 1: Comprehensive error handling
Future<void> errorHandlingExample() async {
  print('=== Error Handling Example ===');

  final config = await TranslatorConfig.fromFile();
  final translator = ArbTranslator(config);

  try {
    await translator.generateArbForLanguage('nonexistent.arb', 'fr');
  } on ArbFileNotFoundException catch (e) {
    print('File not found: ${e.filePath}');
    // Handle missing source file
  } on ArbFileFormatException catch (e) {
    print('Invalid ARB format in ${e.filePath}: ${e.details}');
    // Handle malformed ARB files
  } on UnsupportedLanguageException catch (e) {
    print('Unsupported language: ${e.languageCode}');
    // Suggest alternative languages
    final suggestions = suggestLanguageCodes(e.languageCode);
    if (suggestions.isNotEmpty) {
      print('Did you mean: ${suggestions.join(', ')}?');
    }
  } on TranslationApiException catch (e) {
    print('Translation API error (${e.statusCode}): ${e.details}');
    // Handle API failures, implement fallbacks
  } catch (e) {
    print('Unexpected error: $e');
    // Handle unexpected errors
  } finally {
    translator.dispose();
  }
}

/// Example 2: Advanced configuration management
Future<void> configurationManagementExample() async {
  print('\\n=== Configuration Management Example ===');

  // Create environment-specific configurations
  final developmentConfig = const TranslatorConfig(
    maxConcurrentTranslations: 2,
    logLevel: LogLevel.debug,
    validateOutput: true,
    prettyPrintJson: true,
  );

  final productionConfig = const TranslatorConfig(
    maxConcurrentTranslations: 10,
    logLevel: LogLevel.warning,
    validateOutput: true,
    prettyPrintJson: false,
    retryAttempts: 5,
  );

  // Select configuration based on environment
  final isDevelopment = Platform.environment['ENVIRONMENT'] != 'production';
  final config = isDevelopment ? developmentConfig : productionConfig;

  print('Using ${isDevelopment ? 'development' : 'production'} configuration');
  print('- Max concurrent translations: ${config.maxConcurrentTranslations}');
  print('- Log level: ${config.logLevel.name}');
  print('- Retry attempts: ${config.retryAttempts}');

  // Save configuration for later use
  await config.saveToFile('config/${isDevelopment ? 'dev' : 'prod'}.yaml');
}

/// Example 3: Direct translation service usage
Future<void> translationServiceExample() async {
  print('\\n=== Translation Service Example ===');

  final config = await TranslatorConfig.fromFile();
  final translationService = TranslationService(config);

  try {
    // Single text translation
    final translatedText = await translationService.translateText(
      'Hello, world!',
      'fr',
      sourceLang: 'en',
    );
    print('Translated text: $translatedText');

    // Batch text translation
    final textsToTranslate = {
      'greeting': 'Hello',
      'farewell': 'Goodbye',
      'thanks': 'Thank you',
    };

    final translatedBatch = await translationService.translateBatch(
      textsToTranslate,
      'es',
    );

    print('Batch translation results:');
    for (final entry in translatedBatch.entries) {
      print('  ${entry.key}: ${entry.value}');
    }
  } finally {
    translationService.dispose();
  }
}

/// Example 4: Batch processing with progress tracking
Future<void> batchProcessingExample() async {
  print('\\n=== Batch Processing Example ===');

  final config = const TranslatorConfig(
    maxConcurrentTranslations: 3,
    logLevel: LogLevel.info,
  );

  final logger = TranslatorLogger();
  logger.initialize(config.logLevel);

  final translator = ArbTranslator(config);

  try {
    // Define source files and target languages
    final sourceFiles = ['lib/l10n/app_en.arb'];
    final targetLanguages = ['fr', 'es', 'de', 'it', 'pt'];

    // Process each source file
    for (final sourceFile in sourceFiles) {
      if (!await File(sourceFile).exists()) {
        logger.warning('Skipping missing file: $sourceFile');
        continue;
      }

      logger.info('Processing: $sourceFile');

      // Validate source file first
      try {
        final content = await ArbHelper.readArbFile(sourceFile);
        final issues = ArbHelper.validateArbContent(content);

        if (issues.isNotEmpty) {
          logger.warning('Validation issues in $sourceFile:');
          for (final issue in issues) {
            logger.warning('  - $issue');
          }
        }
      } catch (e) {
        logger.error('Failed to validate $sourceFile: $e');
        continue;
      }

      // Translate to all target languages
      final results = await translator.generateMultipleLanguages(
        sourceFile,
        targetLanguages,
        overwrite: true,
      );

      // Report results
      final successful = results.values.where((path) => path.isNotEmpty).length;
      final failed = targetLanguages.length - successful;

      logger.info(
          'Results for $sourceFile: $successful successful, $failed failed');
    }
  } finally {
    translator.dispose();
  }
}

/// Example 5: CI/CD integration pattern
Future<void> cicdIntegrationExample() async {
  print('\\n=== CI/CD Integration Example ===');

  // Configuration for CI/CD environment
  final ciConfig = const TranslatorConfig(
    maxConcurrentTranslations: 5,
    logLevel: LogLevel.warning, // Less verbose for CI
    validateOutput: true,
    retryAttempts: 3,
    requestTimeoutMs: 60000, // Longer timeout for CI
  );

  final logger = TranslatorLogger();
  logger.initialize(ciConfig.logLevel);

  try {
    // Step 1: Validate all source ARB files
    final sourceFiles = ['lib/l10n/app_en.arb'];
    var validationPassed = true;

    for (final sourceFile in sourceFiles) {
      if (!await File(sourceFile).exists()) {
        logger.error('Source file not found: $sourceFile');
        validationPassed = false;
        continue;
      }

      try {
        final content = await ArbHelper.readArbFile(sourceFile);
        final issues = ArbHelper.validateArbContent(content);

        if (issues.isNotEmpty) {
          logger.error('Validation failed for $sourceFile:');
          for (final issue in issues) {
            logger.error('  - $issue');
          }
          validationPassed = false;
        } else {
          logger.info('✅ Validation passed: $sourceFile');
        }
      } catch (e) {
        logger.error('Failed to validate $sourceFile: $e');
        validationPassed = false;
      }
    }

    if (!validationPassed) {
      logger.error('❌ Validation failed. Stopping CI/CD process.');
      exit(1);
    }

    // Step 2: Generate translations for required languages
    final requiredLanguages =
        Platform.environment['REQUIRED_LANGUAGES']?.split(',') ??
            ['fr', 'es', 'de'];

    logger.info('Generating translations for: ${requiredLanguages.join(', ')}');

    final translator = ArbTranslator(ciConfig);
    var allSuccessful = true;

    for (final sourceFile in sourceFiles) {
      final results = await translator.generateMultipleLanguages(
        sourceFile,
        requiredLanguages,
        overwrite: true,
      );

      // Check if all translations were successful
      for (final lang in requiredLanguages) {
        final path = results[lang];
        if (path == null || path.isEmpty) {
          logger.error('❌ Failed to generate translation for $lang');
          allSuccessful = false;
        } else {
          logger.info('✅ Generated: $path');
        }
      }
    }

    translator.dispose();

    if (!allSuccessful) {
      logger.error('❌ Some translations failed. CI/CD process failed.');
      exit(1);
    }

    logger.info('✅ All translations generated successfully!');
  } catch (e) {
    logger.error('❌ CI/CD process failed: $e');
    exit(1);
  }
}
