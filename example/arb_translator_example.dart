/// Example of using ARB Translator Gen Z programmatically.
///
/// This example demonstrates how to:
/// 1. Load configuration
/// 2. Translate ARB files to specific languages
/// 3. Handle errors gracefully
/// 4. Use advanced features
library;

import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  // Example 1: Basic translation
  await basicTranslationExample();

  // Example 2: Batch translation with custom configuration
  await batchTranslationExample();

  // Example 3: ARB file validation
  await validationExample();

  // Example 4: Language utilities
  languageUtilityExamples();
}

/// Example 1: Basic translation to a single language
Future<void> basicTranslationExample() async {
  print('=== Basic Translation Example ===');

  try {
    // Load default configuration
    final config = await TranslatorConfig.fromFile();

    // Initialize logger
    final logger = TranslatorLogger();
    logger.initialize(config.logLevel);

    // Create translator
    final translator = ArbTranslator(config);

    // Translate to French
    final outputPath = await translator.generateArbForLanguage(
      'lib/l10n/app_en.arb',
      'fr',
    );

    print('✅ Translation completed: $outputPath');

    // Clean up
    translator.dispose();
  } catch (e) {
    print('❌ Translation failed: $e');
  }
}

/// Example 2: Batch translation with custom configuration
Future<void> batchTranslationExample() async {
  print(r'\n=== Batch Translation Example ===');

  try {
    // Create custom configuration
    const customConfig = TranslatorConfig(
      maxConcurrentTranslations: 3,
      retryAttempts: 5,
    );

    // Initialize logger
    final logger = TranslatorLogger();
    logger.initialize(customConfig.logLevel);

    // Create translator with custom config
    final translator = ArbTranslator(customConfig);

    // Translate to multiple popular languages
    final targetLanguages = ['fr', 'es', 'de', 'it', 'pt'];

    final results = await translator.generateMultipleLanguages(
      'lib/l10n/app_en.arb',
      targetLanguages,
    );

    print('✅ Batch translation completed:');
    for (final entry in results.entries) {
      final languageInfo = getLanguageInfo(entry.key);
      final languageName = languageInfo?.nativeName ?? entry.key;
      print('  - $languageName (${entry.key}): ${entry.value}');
    }

    // Clean up
    translator.dispose();
  } catch (e) {
    print('❌ Batch translation failed: $e');
  }
}

/// Example 3: ARB file validation
Future<void> validationExample() async {
  print(r'\n=== Validation Example ===');

  try {
    // Read ARB file
    final content = await ArbHelper.readArbFile('lib/l10n/app_en.arb');

    // Validate structure
    final issues = ArbHelper.validateArbContent(content);

    if (issues.isEmpty) {
      print('✅ ARB file validation passed');

      // Show file statistics
      final translations = ArbHelper.getTranslations(content);
      final metadata = ArbHelper.getMetadata(content);

      print('  - ${translations.length} translatable entries');
      print('  - ${metadata.length} metadata entries');

      // Check locale
      final locale = content['@@locale'] as String?;
      if (locale != null) {
        final info = getLanguageInfo(locale);
        final languageName = info?.name ?? locale;
        print('  - Source language: $languageName ($locale)');
      }
    } else {
      print('❌ ARB file validation failed:');
      for (final issue in issues) {
        print('  - $issue');
      }
    }
  } catch (e) {
    print('❌ Validation failed: $e');
  }
}

/// Example 4: Language utilities
void languageUtilityExamples() {
  print(r'\n=== Language Utility Examples ===');

  // Get language information
  final frenchInfo = getLanguageInfo('fr');
  if (frenchInfo != null) {
    print('French: ${frenchInfo.name} - ${frenchInfo.nativeName}');
    print('RTL: ${frenchInfo.isRightToLeft}');
  }

  // Validate language codes
  try {
    final validCode = validateLangCode('ES'); // Case insensitive
    print('Validated: ES -> $validCode');
  } catch (e) {
    print('Invalid language code: $e');
  }

  // Get suggestions for typos
  final suggestions = suggestLanguageCodes('fren');
  print('Suggestions for "fren": $suggestions');

  // Show popular languages
  print('Popular languages: ${popularLanguageCodes.take(5).join(', ')}');

  // Show RTL languages
  final rtlLanguages = rightToLeftLanguages.take(3);
  print('RTL languages: $rtlLanguages');

  // Format language list
  final formatted = formatLanguageList(['en', 'fr', 'de']);
  print('Formatted list: ${formatted.join(', ')}');
}
