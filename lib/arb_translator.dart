import 'dart:io';
import 'dart:math';

import 'package:arb_translator_gen_z/arb_helper.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:arb_translator_gen_z/src/format_handlers/format_handler.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:arb_translator_gen_z/translator.dart';
import 'package:path/path.dart' as p;

/// Backward-compatible alias for [LocalizationTranslator].
typedef ArbTranslator = LocalizationTranslator;

/// Enhanced localization file translator with parallel processing and comprehensive error handling.
///
/// Supports multiple localization file formats (ARB, JSON, YAML) with concurrent
/// string translation, context-aware AI providers, and built-in retry logic.
///
/// ## Quick Start
///
/// ```dart
/// final translator = LocalizationTranslator(TranslatorConfig());
/// try {
///   // Translate to French
///   await translator.generateForLanguage('lib/l10n/app_en.arb', 'fr');
///
///   // Translate to multiple languages concurrently
///   await translator.generateMultipleLanguages(
///     'lib/l10n/app_en.arb',
///     ['es', 'de', 'it', 'pt'],
///   );
/// } finally {
///   translator.dispose();
/// }
/// ```
class LocalizationTranslator {
  /// Creates a [LocalizationTranslator] with the given [config].
  LocalizationTranslator(this._config)
      : _translationService = TranslationService(_config) {
    FormatHandlerRegistry.initializeDefaults();
  }

  final TranslatorConfig _config;
  final TranslationService _translationService;
  final TranslatorLogger _logger = TranslatorLogger();

  /// Generates a translated localization file for the specified [targetLang].
  ///
  /// Strings are translated in parallel batches (controlled by
  /// [TranslatorConfig.maxConcurrentTranslations]) for best performance.
  /// Passing an [outputDir] writes the file to a custom directory instead of
  /// placing it next to the source file.
  ///
  /// ```dart
  /// final path = await translator.generateForLanguage(
  ///   'lib/l10n/app_en.arb',
  ///   'fr',
  ///   outputDir: 'build/l10n',
  /// );
  /// ```
  ///
  /// Returns the path of the generated file.
  ///
  /// Throws [ArbFileNotFoundException] if [sourcePath] does not exist.
  /// Throws [ArbValidationException] if the source has no translatable entries.
  /// Throws [ArbFileWriteException] if writing fails or overwrite is disabled.
  Future<String> generateForLanguage(
    String sourcePath,
    String targetLang, {
    bool overwrite = true,
    String? outputDir,
  }) async {
    _logger.info('Starting translation: $sourcePath -> $targetLang');

    try {
      final sourceContent = await ArbHelper.readArbFile(sourcePath);
      _logger.debug('Source file loaded with ${sourceContent.length} entries');

      final targetPath = _generateTargetPath(
        sourcePath,
        targetLang,
        outputDir: outputDir,
      );

      if (!overwrite && await File(targetPath).exists()) {
        _logger.warning(
          'Target file exists and overwrite is disabled: $targetPath',
        );
        throw ArbFileWriteException(
          targetPath,
          'File exists and overwrite is disabled',
        );
      }

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

      // Parallel batch processing — up to maxConcurrentTranslations at once.
      final translatedResults = await _translateConcurrently(
        sourceContent,
        translations,
        targetLang,
      );

      final targetContent = <String, dynamic>{};

      for (final entry in metadata.entries) {
        if (entry.key == '@@locale') {
          targetContent[entry.key] = targetLang;
        } else if (_config.preserveMetadata) {
          targetContent[entry.key] = entry.value;
        }
      }

      for (final entry in translations.entries) {
        targetContent[entry.key] =
            translatedResults[entry.key] ?? entry.value;
      }

      await ArbHelper.writeArbFile(
        targetPath,
        targetContent,
        prettyPrint: _config.prettyPrintJson,
        createBackup: _config.backupOriginal,
      );

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

  /// Generates ARB files for multiple target languages in concurrent batches.
  ///
  /// Languages are processed in groups of three to balance throughput and
  /// memory usage. Use [outputDir] to write all files to a custom directory.
  ///
  /// ```dart
  /// final results = await translator.generateMultipleLanguages(
  ///   'lib/l10n/app_en.arb',
  ///   ['fr', 'es', 'de'],
  ///   outputDir: 'build/l10n',
  /// );
  /// ```
  ///
  /// Returns a map of language code → generated file path. Languages that
  /// fail are omitted from the result map.
  Future<Map<String, String>> generateMultipleLanguages(
    String sourcePath,
    List<String> targetLanguages, {
    bool overwrite = true,
    String? outputDir,
  }) async {
    _logger.info(
      'Starting batch translation for ${targetLanguages.length} languages',
    );

    final results = <String, String>{};
    final errors = <String, String>{};

    const batchSize = 3;
    for (var i = 0; i < targetLanguages.length; i += batchSize) {
      final batch = targetLanguages.skip(i).take(batchSize).toList();

      final futures = batch.map((lang) async {
        try {
          final outputPath = await generateForLanguage(
            sourcePath,
            lang,
            overwrite: overwrite,
            outputDir: outputDir,
          );
          return MapEntry(lang, outputPath);
        } catch (e) {
          _logger.error('Failed to generate ARB for $lang', e);
          errors[lang] = e.toString();
          return MapEntry(lang, '');
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
      'Batch translation completed: ${results.length} successful, '
      '${errors.length} failed',
    );
    return results;
  }

  /// Disposes of resources used by the translator.
  void dispose() {
    _translationService.dispose();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Translates all [translations] in parallel batches of
  /// [TranslatorConfig.maxConcurrentTranslations].
  Future<Map<String, String>> _translateConcurrently(
    Map<String, dynamic> sourceContent,
    Map<String, dynamic> translations,
    String targetLang,
  ) async {
    final results = <String, String>{};
    final batchSize = max(1, _config.maxConcurrentTranslations);
    final entries = translations.entries.toList();
    var processed = 0;

    for (var i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize).toList();

      final futures = batch.map((entry) async {
        final text = entry.value.toString();
        if (text.trim().isEmpty) return MapEntry(entry.key, text);

        final context =
            ArbHelper.extractTranslationContext(sourceContent, entry.key);
        final description = context['description'] as String?;
        final surrounding = context['surrounding'] as Map<String, String>?;

        try {
          final translated = await _translationService.translateText(
            text,
            targetLang,
            sourceLang: sourceContent['@@locale'] as String?,
            description: description,
            surroundingContext: surrounding,
            keyName: entry.key,
          );
          return MapEntry(entry.key, translated);
        } catch (e) {
          _logger.warning('Failed to translate "${entry.key}": $e');
          return MapEntry(entry.key, text);
        }
      });

      final batchResults = await Future.wait(futures);
      results.addEntries(batchResults);
      processed += batch.length;

      _logger.progress(
        '$processed/${entries.length} strings translated to $targetLang',
      );
    }

    return results;
  }

  String _generateTargetPath(
    String sourcePath,
    String targetLang, {
    String? outputDir,
  }) {
    final patterns = [
      RegExp(r'_[a-z]{2}(-[A-Z]{2})?\.arb$'),
      RegExp(r'\.[a-z]{2}(-[A-Z]{2})?\.arb$'),
    ];

    var targetFileName = sourcePath;
    for (final pattern in patterns) {
      if (pattern.hasMatch(sourcePath)) {
        targetFileName = sourcePath.replaceFirst(pattern, '_$targetLang.arb');
        break;
      }
    }

    if (targetFileName == sourcePath) {
      targetFileName = sourcePath.replaceFirst('.arb', '_$targetLang.arb');
    }

    if (outputDir != null) {
      return p.join(outputDir, p.basename(targetFileName));
    }

    return targetFileName;
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

// ── Deprecated top-level function ─────────────────────────────────────────

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
