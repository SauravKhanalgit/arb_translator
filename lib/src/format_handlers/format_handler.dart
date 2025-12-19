import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';

/// Base class for localization file format handlers.
///
/// Supports multiple formats like ARB, JSON, YAML, CSV, and PO files.
abstract class FormatHandler {
  /// File extension for this format (without dot).
  String get extension;

  /// Human-readable name of the format.
  String get name;

  /// Reads a localization file and returns translations as a Map.
  Future<Map<String, dynamic>> readFile(String filePath);

  /// Writes translations to a file in the appropriate format.
  Future<void> writeFile(String filePath, Map<String, dynamic> translations, {
    bool prettyPrint = true,
    bool createBackup = false,
  });

  /// Validates the format-specific structure.
  List<String> validateContent(Map<String, dynamic> content);

  /// Converts translations to the format's specific structure.
  Map<String, dynamic> convertToFormat(Map<String, dynamic> translations);

  /// Extracts translatable strings from the format.
  Map<String, String> extractTranslatableStrings(Map<String, dynamic> content);

  /// Gets the locale identifier from the file content.
  String? getLocale(Map<String, dynamic> content);
}

/// Registry of available format handlers.
class FormatHandlerRegistry {
  static final Map<String, FormatHandler> _handlers = {};

  /// Registers a format handler.
  static void register(FormatHandler handler) {
    _handlers[handler.extension] = handler;
  }

  /// Gets a handler for the given file extension.
  static FormatHandler? getHandler(String extension) {
    return _handlers[extension.toLowerCase()];
  }

  /// Gets a handler for the given file path.
  static FormatHandler? getHandlerForFile(String filePath) {
    final extension = filePath.split('.').last;
    return getHandler(extension);
  }

  /// Gets all supported extensions.
  static List<String> get supportedExtensions => _handlers.keys.toList();

  /// Initializes default handlers.
  static void initializeDefaults() {
    register(ArbHandler());
    register(JsonHandler());
    register(YamlHandler());
    register(CsvHandler());
  }
}

/// ARB format handler.
class ArbHandler extends FormatHandler {
  @override
  String get extension => 'arb';

  @override
  String get name => 'ARB (Application Resource Bundle)';

  @override
  Future<Map<String, dynamic>> readFile(String filePath) async {
    return readArbFile(filePath);
  }

  @override
  Future<void> writeFile(String filePath, Map<String, dynamic> translations, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    await writeArbFile(filePath, translations,
        prettyPrint: prettyPrint, createBackup: createBackup);
  }

  @override
  List<String> validateContent(Map<String, dynamic> content) {
    return validateArbContent(content);
  }

  @override
  Map<String, dynamic> convertToFormat(Map<String, dynamic> translations) {
    return translations; // ARB is already in the correct format
  }

  @override
  Map<String, String> extractTranslatableStrings(Map<String, dynamic> content) {
    return getTranslations(content);
  }

  @override
  String? getLocale(Map<String, dynamic> content) {
    return content['@@locale'] as String?;
  }
}

/// JSON format handler.
class JsonHandler extends FormatHandler {
  @override
  String get extension => 'json';

  @override
  String get name => 'JSON';

  @override
  Future<Map<String, dynamic>> readFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  }

  @override
  Future<void> writeFile(String filePath, Map<String, dynamic> translations, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    final file = File(filePath);

    if (createBackup && await file.exists()) {
      final backupPath = '$filePath.backup';
      await file.copy(backupPath);
    }

    final encoder = prettyPrint
        ? JsonEncoder.withIndent('  ')
        : JsonEncoder();

    await file.writeAsString(encoder.convert(translations));
  }

  @override
  List<String> validateContent(Map<String, dynamic> content) {
    final issues = <String>[];

    if (content.isEmpty) {
      issues.add('JSON file is empty');
    }

    // Check for nested objects (not supported for simple translation)
    for (final value in content.values) {
      if (value is! String) {
        issues.add('JSON translation files should contain only string values');
        break;
      }
    }

    return issues;
  }

  @override
  Map<String, dynamic> convertToFormat(Map<String, dynamic> translations) {
    return translations;
  }

  @override
  Map<String, String> extractTranslatableStrings(Map<String, dynamic> content) {
    final translations = <String, String>{};

    content.forEach((key, value) {
      if (value is String && !key.startsWith('@')) {
        translations[key] = value;
      }
    });

    return translations;
  }

  @override
  String? getLocale(Map<String, dynamic> content) {
    // Try to extract locale from filename or content
    return content['_locale'] as String? ?? content['locale'] as String?;
  }
}

/// YAML format handler.
class YamlHandler extends FormatHandler {
  @override
  String get extension => 'yaml';

  @override
  String get name => 'YAML';

  @override
  Future<Map<String, dynamic>> readFile(String filePath) async {
    // Note: This would require yaml package dependency
    // For now, treat as JSON
    final file = File(filePath);
    final content = await file.readAsString();

    // Simple YAML-like parsing (basic implementation)
    final lines = content.split('\n');
    final result = <String, dynamic>{};

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        if (value.startsWith('"') && value.endsWith('"')) {
          result[key] = value.substring(1, value.length - 1);
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }

  @override
  Future<void> writeFile(String filePath, Map<String, dynamic> translations, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    final file = File(filePath);

    if (createBackup && await file.exists()) {
      final backupPath = '$filePath.backup';
      await file.copy(backupPath);
    }

    final buffer = StringBuffer();
    buffer.writeln('# Generated by ARB Translator');

    translations.forEach((key, value) {
      buffer.writeln('$key: "$value"');
    });

    await file.writeAsString(buffer.toString());
  }

  @override
  List<String> validateContent(Map<String, dynamic> content) {
    final issues = <String>[];

    if (content.isEmpty) {
      issues.add('YAML file is empty');
    }

    return issues;
  }

  @override
  Map<String, dynamic> convertToFormat(Map<String, dynamic> translations) {
    return translations;
  }

  @override
  Map<String, String> extractTranslatableStrings(Map<String, dynamic> content) {
    final translations = <String, String>{};

    content.forEach((key, value) {
      if (value is String && !key.startsWith('@') && !key.startsWith('_')) {
        translations[key] = value;
      }
    });

    return translations;
  }

  @override
  String? getLocale(Map<String, dynamic> content) {
    return content['_locale'] as String?;
  }
}

/// CSV format handler for localization.
class CsvHandler extends FormatHandler {
  @override
  String get extension => 'csv';

  @override
  String get name => 'CSV';

  @override
  Future<Map<String, dynamic>> readFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final lines = content.split('\n');

    if (lines.isEmpty) {
      return {};
    }

    // First line is headers
    final headers = _parseCsvLine(lines.first);
    final result = <String, dynamic>{};

    // Find key and value columns
    final keyIndex = headers.indexOf('key');
    final valueIndex = headers.indexOf('value') != -1 ? headers.indexOf('value') :
                      headers.indexOf(headers.firstWhere((h) => h != 'key', orElse: () => ''));

    if (keyIndex == -1) {
      throw FormatException('CSV must have a "key" column');
    }

    // Parse data rows
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = _parseCsvLine(lines[i]);
      if (values.length > keyIndex) {
        final key = values[keyIndex];
        final value = valueIndex != -1 && values.length > valueIndex
            ? values[valueIndex]
            : '';

        result[key] = value;
      }
    }

    return result;
  }

  @override
  Future<void> writeFile(String filePath, Map<String, dynamic> translations, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    final file = File(filePath);

    if (createBackup && await file.exists()) {
      final backupPath = '$filePath.backup';
      await file.copy(backupPath);
    }

    final buffer = StringBuffer();
    buffer.writeln('key,value');

    translations.forEach((key, value) {
      // Escape commas and quotes in CSV
      final escapedKey = key.replaceAll('"', '""');
      final escapedValue = value.toString().replaceAll('"', '""');
      buffer.writeln('"$escapedKey","$escapedValue"');
    });

    await file.writeAsString(buffer.toString());
  }

  @override
  List<String> validateContent(Map<String, dynamic> content) {
    final issues = <String>[];

    if (content.isEmpty) {
      issues.add('CSV file is empty');
    }

    return issues;
  }

  @override
  Map<String, dynamic> convertToFormat(Map<String, dynamic> translations) {
    return translations;
  }

  @override
  Map<String, String> extractTranslatableStrings(Map<String, dynamic> content) {
    final translations = <String, String>{};

    content.forEach((key, value) {
      if (value is String && value.isNotEmpty) {
        translations[key] = value;
      }
    });

    return translations;
  }

  @override
  String? getLocale(Map<String, dynamic> content) {
    return content['_locale'] as String?;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          current += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }

    result.add(current); // Add last field
    return result;
  }
}

  Future<Map<String, dynamic>> readArbFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ArbFileNotFoundException(path);
    }

    try {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      return data;
    } catch (e) {
      throw ArbFileFormatException(path, 'Invalid JSON format: $e');
    }
  }

  Future<void> writeArbFile(String path, Map<String, dynamic> content, {
    bool prettyPrint = true,
    bool createBackup = false,
  }) async {
    final file = File(path);

    if (createBackup && await file.exists()) {
      final backupPath = '$path.backup';
      await file.copy(backupPath);
    }

    final encoder = prettyPrint
        ? JsonEncoder.withIndent('  ')
        : JsonEncoder();

    await file.writeAsString(encoder.convert(content));
  }

  List<String> validateArbContent(Map<String, dynamic> content) {
    final issues = <String>[];

    if (content.isEmpty) {
      issues.add('ARB file is empty');
      return issues;
    }

    // Check for @@locale
    if (!content.containsKey('@@locale')) {
      issues.add('Missing @@locale metadata');
    } else if (content['@@locale'] == null || (content['@@locale'] as String).isEmpty) {
      issues.add('@@locale is empty');
    }

    // Check for translations
    final translations = getTranslations(content);
    if (translations.isEmpty) {
      issues.add('No translatable content found');
    }

    // Validate key formats and values
    content.forEach((key, value) {
      if (key.startsWith('@@')) {
        // Metadata keys
        if (value == null) {
          issues.add('Metadata key "$key" has null value');
        }
      } else if (!key.startsWith('@')) {
        // Translation keys
        if (value == null) {
          issues.add('Translation key "$key" has null value');
        } else if (value is! String) {
          issues.add('Translation key "$key" must have string value');
        } else if ((value as String).isEmpty) {
          issues.add('Translation key "$key" has empty value');
        }
      }
    });

    return issues;
  }

  Map<String, String> getTranslations(Map<String, dynamic> content) {
    final translations = <String, String>{};

    content.forEach((key, value) {
      if (!key.startsWith('@') && value is String) {
        translations[key] = value;
      }
    });

    return translations;
  }
