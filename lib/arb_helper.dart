import 'dart:convert';
import 'dart:io';

import 'src/exceptions/arb_exceptions.dart';

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
    final backupPath = '${filePath}.backup.$timestamp';
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
            'Potential duplicate key: "$key" vs "${lowerCaseKeys[lowerKey]}"');
      }
      lowerCaseKeys[lowerKey] = key;
    }

    return issues;
  }
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
