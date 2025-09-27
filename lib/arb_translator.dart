import 'dart:io';

import 'arb_helper.dart';
import 'src/config/translator_config.dart';
import 'src/exceptions/arb_exceptions.dart';
import 'src/exceptions/translation_exceptions.dart';
import 'src/logging/translator_logger.dart';
import 'translator.dart';

/// Enhanced ARB file translator with comprehensive error handling and configuration.
///
/// This class provides robust translation capabilities for ARB (Application Resource Bundle)
/// files with advanced features like retry logic, rate limiting, and validation.
class ArbTranslator {
  /// Creates an [ArbTranslator] with the given [config].
  ArbTranslator(this._config)
      : _translationService = TranslationService(_config);

  final TranslatorConfig _config;
  final TranslationService _translationService;
  final TranslatorLogger _logger = TranslatorLogger();

  /// Generates a translated ARB file for the specified [targetLang] based on the
  /// [sourcePath] ARB file.
  ///
  /// This method reads the source ARB file, translates all user-facing text
  /// entries (preserving metadata), validates the output, and writes a new ARB
  /// file for the target language.
  ///
  /// Example:
  /// ```dart
  /// final translator = ArbTranslator(config);
  /// await translator.generateArbForLanguage('lib/l10n/app_en.arb', 'fr');
  /// // Generates lib/l10n/app_fr.arb
  /// ```
  ///
  /// [sourcePath]: The path to the source ARB file (e.g., 'lib/l10n/app_en.arb').
  /// [targetLang]: The ISO-639 language code for the target translation (e.g., 'fr').
  /// [overwrite]: Whether to overwrite existing files (default: true).
  ///
  /// Returns a [Future<String>] with the path to the generated file.
  ///
  /// Throws [ArbFileNotFoundException] if source file doesn't exist.
  /// Throws [ArbFileFormatException] if source file has invalid format.
  /// Throws [TranslationException] if translation fails.
  /// Throws [ArbFileWriteException] if output file cannot be written.
  Future<String> generateArbForLanguage(
    String sourcePath,
    String targetLang, {
    bool overwrite = true,
  }) async {
    _logger.info('Starting translation: $sourcePath -> $targetLang');

    try {
      // Read and validate source ARB file
      final sourceContent = await ArbHelper.readArbFile(sourcePath);
      _logger.debug('Source file loaded with ${sourceContent.length} entries');

      // Check if target file exists and handle overwrite
      final targetPath = _generateTargetPath(sourcePath, targetLang);
      if (!overwrite && await File(targetPath).exists()) {
        _logger.warning(
            'Target file exists and overwrite is disabled: $targetPath');
        throw ArbFileWriteException(
            targetPath, 'File exists and overwrite is disabled');
      }

      // Extract translations (non-metadata entries)
      final translations = ArbHelper.getTranslations(sourceContent);
      final metadata = ArbHelper.getMetadata(sourceContent);

      if (translations.isEmpty) {
        _logger.warning('No translatable content found in source file');
        throw ArbValidationException(
            sourcePath, ['No translatable content found']);
      }

      _logger.info('Found ${translations.length} entries to translate');

      // Perform translations with batch processing
      final translatedTexts = <String, String>{};
      for (final entry in translations.entries) {
        final text = entry.value.toString();
        if (text.trim().isNotEmpty) {
          translatedTexts[entry.key] = text;
        }
      }

      final translatedResults = await _translationService.translateBatch(
        translatedTexts,
        targetLang,
      );

      // Build target content
      final targetContent = <String, dynamic>{};

      // Add metadata with updated locale
      for (final entry in metadata.entries) {
        if (entry.key == '@@locale') {
          targetContent[entry.key] = targetLang;
        } else if (_config.preserveMetadata) {
          targetContent[entry.key] = entry.value;
        }
      }

      // Add translations
      for (final entry in translations.entries) {
        final translatedText = translatedResults[entry.key];
        targetContent[entry.key] = translatedText ?? entry.value;

        if (translatedText != null) {
          _logger.debug('Translated ${entry.key}: "$translatedText"');
        }
      }

      // Write target ARB file
      await ArbHelper.writeArbFile(
        targetPath,
        targetContent,
        prettyPrint: _config.prettyPrintJson,
        createBackup: _config.backupOriginal,
      );

      // Validate output if configured
      if (_config.validateOutput) {
        await _validateGeneratedFile(targetPath);
      }

      _logger.success('Generated $targetPath successfully!');
      return targetPath;
    } catch (e) {
      _logger.error('Failed to generate ARB file for $targetLang', e);
      rethrow;
    }
  }

  /// Generates ARB files for multiple target languages.
  ///
  /// Processes translations concurrently with proper throttling to respect
  /// API rate limits.
  ///
  /// [sourcePath]: The path to the source ARB file.
  /// [targetLanguages]: List of target language codes.
  /// [overwrite]: Whether to overwrite existing files.
  ///
  /// Returns a [Future<Map<String, String>>] mapping language codes to generated file paths.
  Future<Map<String, String>> generateMultipleLanguages(
    String sourcePath,
    List<String> targetLanguages, {
    bool overwrite = true,
  }) async {
    _logger.info(
        'Starting batch translation for ${targetLanguages.length} languages');

    final results = <String, String>{};
    final errors = <String, String>{};

    // Process languages in smaller batches to manage memory and API load
    const batchSize = 3;
    for (var i = 0; i < targetLanguages.length; i += batchSize) {
      final batch = targetLanguages.skip(i).take(batchSize).toList();

      final futures = batch.map((lang) async {
        try {
          final outputPath = await generateArbForLanguage(
            sourcePath,
            lang,
            overwrite: overwrite,
          );
          return MapEntry(lang, outputPath);
        } catch (e) {
          _logger.error('Failed to generate ARB for $lang', e);
          errors[lang] = e.toString();
          return MapEntry(lang, ''); // Empty path indicates failure
        }
      });

      final batchResults = await Future.wait(futures);

      for (final result in batchResults) {
        if (result.value.isNotEmpty) {
          results[result.key] = result.value;
        }
      }
    }

    if (errors.isNotEmpty) {
      _logger.warning('Some translations failed: ${errors.keys.join(', ')}');
    }

    _logger.success(
        'Batch translation completed: ${results.length} successful, ${errors.length} failed');
    return results;
  }

  /// Disposes of resources used by the translator.
  void dispose() {
    _translationService.dispose();
  }

  String _generateTargetPath(String sourcePath, String targetLang) {
    // Handle different ARB filename patterns
    final patterns = [
      RegExp(r'_[a-z]{2}(-[A-Z]{2})?\.arb$'), // app_en.arb or app_en-US.arb
      RegExp(r'\.[a-z]{2}(-[A-Z]{2})?\.arb$'), // app.en.arb or app.en-US.arb
      RegExp(r'\.arb$'), // app.arb (fallback)
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(sourcePath)) {
        return sourcePath.replaceFirst(pattern, '_$targetLang.arb');
      }
    }

    // Fallback: insert language before extension
    return sourcePath.replaceFirst('.arb', '_$targetLang.arb');
  }

  Future<void> _validateGeneratedFile(String filePath) async {
    try {
      final content = await ArbHelper.readArbFile(filePath);
      final issues = ArbHelper.validateArbContent(content);

      if (issues.isNotEmpty) {
        _logger.warning(
            'Validation issues in generated file: ${issues.join(', ')}');
      } else {
        _logger.debug('Generated file validation passed');
      }
    } catch (e) {
      _logger.warning('Failed to validate generated file: $e');
    }
  }
}

// Legacy function for backward compatibility
/// @deprecated Use [ArbTranslator.generateArbForLanguage] instead.
@Deprecated('Use ArbTranslator.generateArbForLanguage instead')
Future<void> generateArbForLanguage(
  String sourcePath,
  String targetLang,
) async {
  final config = await TranslatorConfig.fromFile();
  final logger = TranslatorLogger();
  logger.initialize(config.logLevel);

  final translator = ArbTranslator(config);
  try {
    await translator.generateArbForLanguage(sourcePath, targetLang);
  } finally {
    translator.dispose();
  }
}
