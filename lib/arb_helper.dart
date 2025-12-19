import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:collection/collection.dart';

/// Enhanced ARB file operations with comprehensive validation and error handling.
///
/// This class provides robust methods for reading, writing, and validating
/// ARB (Application Resource Bundle) files with detailed error reporting.
class ArbHelper {
  /// Private constructor to prevent instantiation.
  const ArbHelper._();

  /// Reads an ARB file from the given [filePath] and returns its content as a Map.
  ///
  /// Performs validation to ensure the file contains valid JSON and follows
  /// ARB format conventions.
  ///
  /// Example:
  /// ```dart
  /// final content = await ArbHelper.readArbFile('lib/l10n/app_en.arb');
  /// print(content['appTitle']); // prints the title string
  /// ```
  ///
  /// [filePath]: The file path to the ARB file.
  ///
  /// Returns a [Future<Map<String, dynamic>>] containing the key-value pairs
  /// from the ARB file.
  ///
  /// Throws [ArbFileNotFoundException] if the file does not exist.
  /// Throws [ArbFileFormatException] if the file contains invalid JSON.
  /// Throws [ArbValidationException] if the file doesn't follow ARB conventions.
  static Future<Map<String, dynamic>> readArbFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArbFileNotFoundException(filePath);
    }

    try {
      final content = await file.readAsString();

      final Map<String, dynamic> arbData;
      try {
        arbData = json.decode(content) as Map<String, dynamic>;
      } catch (e) {
        throw ArbFileFormatException(filePath, 'Invalid JSON format: $e');
      }

      // Validate ARB file structure
      final validationIssues = _validateArbStructure(arbData);
      if (validationIssues.isNotEmpty) {
        throw ArbValidationException(filePath, validationIssues);
      }

      return arbData;
    } catch (e) {
      if (e is ArbException) rethrow;
      throw ArbFileFormatException(filePath, 'Failed to read file: $e');
    }
  }

  /// Writes the given [content] Map to an ARB file at the specified [filePath].
  ///
  /// Creates parent directories if they don't exist and optionally creates
  /// backup files before overwriting existing files.
  ///
  /// Example:
  /// ```dart
  /// await ArbHelper.writeArbFile(
  ///   'lib/l10n/app_fr.arb',
  ///   {'appTitle': 'Mon App'},
  ///   prettyPrint: true,
  ///   createBackup: true,
  /// );
  /// ```
  ///
  /// [filePath]: The file path where the ARB file will be written.
  /// [content]: A Map containing the key-value pairs to write.
  /// [prettyPrint]: Whether to format JSON with indentation (default: true).
  /// [createBackup]: Whether to create a backup before overwriting (default: false).
  ///
  /// Returns a [Future<void>] that completes when the file has been written.
  ///
  /// Throws [ArbFileWriteException] if writing fails.
  /// Throws [ArbValidationException] if content validation fails.
  static Future<void> writeArbFile(
    String filePath,
    Map<String, dynamic> content, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    // Validate content before writing
    final validationIssues = _validateArbStructure(content);
    if (validationIssues.isNotEmpty) {
      throw ArbValidationException(filePath, validationIssues);
    }

    try {
      final file = File(filePath);

      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      // Create backup if requested and file exists
      if (createBackup && await file.exists()) {
        await _createBackup(filePath);
      }

      // Encode JSON
      final encoder = prettyPrint
          ? const JsonEncoder.withIndent('  ')
          : const JsonEncoder();
      final jsonContent = encoder.convert(content);

      // Write file
      await file.writeAsString(jsonContent);
    } catch (e) {
      throw ArbFileWriteException(filePath, e.toString());
    }
  }

  /// Validates the structure of an ARB file content.
  ///
  /// Checks for common issues like:
  /// - Missing @@locale entry
  /// - Invalid metadata format
  /// - Empty or null values
  /// - Inconsistent key naming
  ///
  /// [content]: The ARB content to validate.
  ///
  /// Returns a [List<String>] of validation issues (empty if valid).
  static List<String> validateArbContent(Map<String, dynamic> content) {
    return _validateArbStructure(content);
  }

  /// Gets metadata entries from ARB content.
  ///
  /// Returns a map containing only entries that start with '@'.
  ///
  /// [content]: The ARB content to extract metadata from.
  ///
  /// Returns a [Map<String, dynamic>] containing metadata entries.
  static Map<String, dynamic> getMetadata(Map<String, dynamic> content) {
    return Map.fromEntries(
      content.entries.where((entry) => entry.key.startsWith('@')),
    );
  }

  /// Gets translation entries from ARB content.
  ///
  /// Returns a map containing only entries that don't start with '@'.
  ///
  /// [content]: The ARB content to extract translations from.
  ///
  /// Returns a [Map<String, dynamic>] containing translation entries.
  static Map<String, dynamic> getTranslations(Map<String, dynamic> content) {
    return Map.fromEntries(
      content.entries.where((entry) => !entry.key.startsWith('@')),
    );
  }

  /// Creates a backup of the specified file.
  static Future<void> _createBackup(String filePath) async {
    final file = File(filePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '$filePath.backup.$timestamp';
    await file.copy(backupPath);
  }

  /// Validates ARB file structure and returns list of issues.
  static List<String> _validateArbStructure(Map<String, dynamic> content) {
    final issues = <String>[];

    // Check if file is empty
    if (content.isEmpty) {
      issues.add('ARB file is empty');
      return issues;
    }

    // Check for @@locale entry
    if (!content.containsKey('@@locale')) {
      issues.add('Missing required @@locale entry');
    } else {
      final locale = content['@@locale'];
      if (locale == null || locale.toString().trim().isEmpty) {
        issues.add('@@locale entry is empty or null');
      }
    }

    // Validate metadata entries
    for (final entry in content.entries) {
      if (entry.key.startsWith('@')) {
        if (entry.key == '@' || entry.key.length == 1) {
          issues.add('Invalid metadata key: "${entry.key}"');
        }
        continue;
      }

      // Validate translation entries
      if (entry.key.trim().isEmpty) {
        issues.add('Empty translation key found');
      }

      if (entry.value == null) {
        issues.add('Null value for key "${entry.key}"');
      } else if (entry.value.toString().trim().isEmpty) {
        issues.add('Empty value for key "${entry.key}"');
      }
    }

    // Check for duplicate keys (case-insensitive)
    final lowerCaseKeys = <String, String>{};
    for (final key in content.keys) {
      final lowerKey = key.toLowerCase();
      if (lowerCaseKeys.containsKey(lowerKey) &&
          lowerCaseKeys[lowerKey] != key) {
        issues.add(
          'Potential duplicate key: "$key" vs "${lowerCaseKeys[lowerKey]}"',
        );
      }
      lowerCaseKeys[lowerKey] = key;
    }

    return issues;
  }

  /// Extracts context information for a translation key.
  static Map<String, dynamic> extractTranslationContext(
    Map<String, dynamic> arbContent,
    String key, {
    int contextRadius = 2,
  }) {
    final context = <String, dynamic>{};

    // Get description from @key metadata
    final descriptionKey = '@$key';
    if (arbContent.containsKey(descriptionKey)) {
      final description = arbContent[descriptionKey];
      if (description is Map && description.containsKey('description')) {
        context['description'] = description['description'];
      }
    }

    // Get surrounding keys for context
    final allKeys = arbContent.keys.where((k) => !k.startsWith('@')).toList();
    final keyIndex = allKeys.indexOf(key);

    if (keyIndex != -1) {
      final surroundingContext = <String, String>{};

      // Get keys before current key
      for (var i = max(0, keyIndex - contextRadius); i < keyIndex; i++) {
        final contextKey = allKeys[i];
        final contextValue = arbContent[contextKey]?.toString() ?? '';
        if (contextValue.isNotEmpty && contextValue.length < 100) {
          surroundingContext['prev_${contextKey}'] = contextValue;
        }
      }

      // Get keys after current key
      for (var i = keyIndex + 1; i < min(allKeys.length, keyIndex + contextRadius + 1); i++) {
        final contextKey = allKeys[i];
        final contextValue = arbContent[contextKey]?.toString() ?? '';
        if (contextValue.isNotEmpty && contextValue.length < 100) {
          surroundingContext['next_${contextKey}'] = contextValue;
        }
      }

      if (surroundingContext.isNotEmpty) {
        context['surrounding'] = surroundingContext;
      }
    }

    // Add locale information
    final locale = arbContent['@@locale']?.toString();
    if (locale != null) {
      context['locale'] = locale;
    }

    return context;
  }

  /// Analyzes ARB files for missing translations and inconsistencies.
  static ArbAnalysisResult analyzeArbFiles(
    Map<String, Map<String, dynamic>> arbFiles,
  ) {
    final baseFile = arbFiles.values.first;
    final baseKeys = baseFile.keys.where((k) => !k.startsWith('@')).toSet();

    final analysis = <String, ArbFileAnalysis>{};

    for (final entry in arbFiles.entries) {
      final locale = entry.key;
      final content = entry.value;

      final fileKeys = content.keys.where((k) => !k.startsWith('@')).toSet();
      final missingKeys = baseKeys.difference(fileKeys);
      final extraKeys = fileKeys.difference(baseKeys);

      // Check for placeholder consistency
      final placeholderIssues = <String>[];
      for (final key in fileKeys.intersection(baseKeys)) {
        final baseValue = baseFile[key]?.toString() ?? '';
        final fileValue = content[key]?.toString() ?? '';

        final basePlaceholders = _extractPlaceholders(baseValue);
        final filePlaceholders = _extractPlaceholders(fileValue);

        if (!const SetEquality().equals(basePlaceholders, filePlaceholders)) {
          placeholderIssues.add(key);
        }
      }

      analysis[locale] = ArbFileAnalysis(
        totalKeys: fileKeys.length,
        missingKeys: missingKeys,
        extraKeys: extraKeys,
        placeholderIssues: placeholderIssues,
        completenessPercentage: (fileKeys.length / baseKeys.length) * 100,
      );
    }

    return ArbAnalysisResult(
      baseLocale: baseFile['@@locale']?.toString() ?? 'en',
      baseKeyCount: baseKeys.length,
      fileAnalysis: analysis,
    );
  }

  /// Suggests translations for missing keys based on similar existing translations.
  static Map<String, String> suggestMissingTranslations(
    Map<String, Map<String, dynamic>> arbFiles,
    String targetLocale,
  ) {
    final suggestions = <String, String>{};
    final targetFile = arbFiles[targetLocale];
    final baseFile = arbFiles.values.first;

    if (targetFile == null) return suggestions;

    final baseKeys = baseFile.keys.where((k) => !k.startsWith('@')).toSet();
    final targetKeys = targetFile.keys.where((k) => !k.startsWith('@')).toSet();
    final missingKeys = baseKeys.difference(targetKeys);

    for (final missingKey in missingKeys) {
      // Find similar keys in target file
      final similarTranslations = <String, String>{};
      for (final targetKey in targetKeys) {
        final similarity = _calculateSimilarity(missingKey, targetKey);
        if (similarity > 0.6) { // 60% similarity threshold
          final translation = targetFile[targetKey]?.toString() ?? '';
          if (translation.isNotEmpty) {
            similarTranslations[targetKey] = translation;
          }
        }
      }

      if (similarTranslations.isNotEmpty) {
        // Use the most similar translation as suggestion
        final bestMatch = similarTranslations.entries
            .reduce((a, b) => _calculateSimilarity(missingKey, a.key) >
                             _calculateSimilarity(missingKey, b.key) ? a : b);
        suggestions[missingKey] = bestMatch.value;
      }
    }

    return suggestions;
  }

  static Set<String> _extractPlaceholders(String text) {
    final placeholders = <String>{};
    final placeholderRegex = RegExp(r'\{([^}]+)\}|\$([a-zA-Z_][a-zA-Z0-9_]*)');
    final matches = placeholderRegex.allMatches(text);

    for (final match in matches) {
      final placeholder = match.group(1) ?? match.group(2);
      if (placeholder != null) {
        placeholders.add(placeholder);
      }
    }

    return placeholders;
  }

  static double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aWords = a.toLowerCase().split(RegExp(r'[_\s]+'));
    final bWords = b.toLowerCase().split(RegExp(r'[_\s]+'));

    final commonWords = aWords.where((word) => bWords.contains(word)).length;
    final totalWords = (aWords.length + bWords.length) / 2;

    return totalWords > 0 ? commonWords / totalWords : 0.0;
  }
}

/// Result of ARB file analysis.
class ArbAnalysisResult {
  /// Creates an [ArbAnalysisResult] with the given parameters.
  const ArbAnalysisResult({
    required this.baseLocale,
    required this.baseKeyCount,
    required this.fileAnalysis,
  });

  /// The base locale used for comparison.
  final String baseLocale;

  /// Total number of keys in the base file.
  final int baseKeyCount;

  /// Analysis results for each ARB file.
  final Map<String, ArbFileAnalysis> fileAnalysis;

  /// Gets overall project completeness percentage.
  double get overallCompleteness {
    if (fileAnalysis.isEmpty) return 100.0;

    final totalCompleteness = fileAnalysis.values
        .map((analysis) => analysis.completenessPercentage)
        .reduce((a, b) => a + b);

    return totalCompleteness / fileAnalysis.length;
  }

  /// Gets total number of missing keys across all files.
  int get totalMissingKeys {
    return fileAnalysis.values
        .map((analysis) => analysis.missingKeys.length)
        .fold(0, (a, b) => a + b);
  }
}

/// Analysis result for a single ARB file.
class ArbFileAnalysis {
  /// Creates an [ArbFileAnalysis] with the given parameters.
  const ArbFileAnalysis({
    required this.totalKeys,
    required this.missingKeys,
    required this.extraKeys,
    required this.placeholderIssues,
    required this.completenessPercentage,
  });

  /// Total number of translation keys in this file.
  final int totalKeys;

  /// Keys that are missing compared to the base file.
  final Set<String> missingKeys;

  /// Keys that exist in this file but not in the base file.
  final Set<String> extraKeys;

  /// Keys with placeholder consistency issues.
  final List<String> placeholderIssues;

  /// Completeness percentage (0.0 to 100.0).
  final double completenessPercentage;

  /// Whether this file has any issues.
  bool get hasIssues =>
      missingKeys.isNotEmpty ||
      extraKeys.isNotEmpty ||
      placeholderIssues.isNotEmpty;
}

// Legacy functions for backward compatibility
/// @deprecated Use [ArbHelper.readArbFile] instead.
@Deprecated('Use ArbHelper.readArbFile instead')
Future<Map<String, dynamic>> readArbFile(String path) async {
  return ArbHelper.readArbFile(path);
}

/// @deprecated Use [ArbHelper.writeArbFile] instead.
@Deprecated('Use ArbHelper.writeArbFile instead')
Future<void> writeArbFile(String path, Map<String, dynamic> content) async {
  return ArbHelper.writeArbFile(path, content);
}
