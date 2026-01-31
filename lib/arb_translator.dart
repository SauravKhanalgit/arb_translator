import 'dart:io';

import 'package:arb_translator_gen_z/arb_helper.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:arb_translator_gen_z/src/format_handlers/format_handler.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:arb_translator_gen_z/translator.dart';

/// Enhanced localization file translator with comprehensive error handling and configuration.
///
/// This class provides robust translation capabilities for multiple localization file formats
/// (ARB, JSON, YAML, CSV, PO) with advanced features like retry logic, rate limiting,
/// context-aware translation, and validation.
class LocalizationTranslator {
  /// Creates a [LocalizationTranslator] with the given [config].
  LocalizationTranslator(this._config)
      : _translationService = TranslationService(_config) {
    // Initialize format handlers
    FormatHandlerRegistry.initializeDefaults();
  }

  final TranslatorConfig _config;
  final TranslationService _translationService;
  final TranslatorLogger _logger = TranslatorLogger();

  /// Generates a translated localization file for the specified [targetLang] based on the
  /// [sourcePath] file.
  ///
  /// Supports multiple formats (ARB, JSON, YAML, CSV) and uses context-aware translation
  /// with AI providers for high-quality results.
  ///
  /// Example:
  /// ```dart
  /// final translator = LocalizationTranslator(config);
  /// await translator.generateForLanguage('lib/l10n/app_en.arb', 'fr');
  /// // Generates lib/l10n/app_fr.arb
  /// ```
  ///
  /// [sourcePath]: The path to the source localization file.
  /// [targetLang]: The ISO-639 language code for the target translation.
  /// [overwrite]: Whether to overwrite existing files (default: true).
  ///
  /// Returns a [Future<String>] with the path to the generated file.
  Future<String> generateForLanguage(
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
          'Target file exists and overwrite is disabled: $targetPath',
        );
        throw ArbFileWriteException(
          targetPath,
          'File exists and overwrite is disabled',
        );
      }

      // Extract translations (non-metadata entries)
      final translations = ArbHelper.getTranslations(sourceContent);
      final metadata = ArbHelper.getMetadata(sourceContent);

      if (translations.isEmpty) {
        _logger.warning('No translatable content found in source file');
        throw ArbValidationException(
          sourcePath,
          ['No translatable content found'],
        );
      }

      _logger.info('Found ${translations.length} entries to translate');

      // Perform context-aware translations with batch processing
      final translatedResults = <String, String>{};

      for (final entry in translations.entries) {
        final text = entry.value.toString();
        if (text.trim().isNotEmpty) {
          // Extract context for this translation
          final context =
              ArbHelper.extractTranslationContext(sourceContent, entry.key);
          final description = context['description'] as String?;
          final surrounding = context['surrounding'] as Map<String, String>?;

          try {
            final translatedText = await _translationService.translateText(
              text,
              targetLang,
              sourceLang: sourceContent['@@locale'] as String?,
              description: description,
              surroundingContext: surrounding,
              keyName: entry.key,
            );
            translatedResults[entry.key] = translatedText;
          } catch (e) {
            _logger.warning('Failed to translate ${entry.key}: $e');
            // Keep original text on failure
            translatedResults[entry.key] = text;
          }
        }
      }

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
      'Starting batch translation for ${targetLanguages.length} languages',
    );

    final results = <String, String>{};
    final errors = <String, String>{};

    // Process languages in smaller batches to manage memory and API load
    const batchSize = 3;
    for (var i = 0; i < targetLanguages.length; i += batchSize) {
      final batch = targetLanguages.skip(i).take(batchSize).toList();

      final futures = batch.map((lang) async {
        try {
          final outputPath = await generateForLanguage(
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
      'Batch translation completed: ${results.length} successful, ${errors.length} failed',
    );
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
          'Validation issues in generated file: ${issues.join(', ')}',
        );
      } else {
        _logger.debug('Generated file validation passed');
      }
    } catch (e) {
      _logger.warning('Failed to validate generated file: $e');
    }
  }
}

// Legacy function for backward compatibility
/// @deprecated Use [LocalizationTranslator.generateForLanguage] instead.
@Deprecated('Use LocalizationTranslator.generateForLanguage instead')
Future<void> generateArbForLanguage(
  String sourcePath,
  String targetLang,
) async {
  final config = await TranslatorConfig.fromFile();
  final logger = TranslatorLogger();
  logger.initialize(config.logLevel);

  final translator = LocalizationTranslator(config);
  try {
    await translator.generateForLanguage(sourcePath, targetLang);
  } finally {
    translator.dispose();
  }
}
