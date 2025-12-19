import 'dart:convert';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:intl/intl.dart';

/// Represents a complex string with placeholders and special patterns.
class ComplexString {
  /// Creates a [ComplexString] from the given text.
  factory ComplexString.parse(String text) {
    final placeholders = <String>[];
    final datePatterns = <String>[];
    final numberPatterns = <String>[];
    final segments = <String>[];

    // Extract placeholders like {name}, $variable, %s
    final placeholderRegex = RegExp(r'\{([^}]+)\}|\$([a-zA-Z_][a-zA-Z0-9_]*)|%\w');
    final placeholdersFound = placeholderRegex.allMatches(text);

    for (final match in placeholdersFound) {
      final placeholder = match.group(0)!;
      if (!placeholders.contains(placeholder)) {
        placeholders.add(placeholder);
      }
    }

    // Extract date patterns
    final dateRegex = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b');
    final datesFound = dateRegex.allMatches(text);
    for (final match in datesFound) {
      datePatterns.add(match.group(0)!);
    }

    // Extract number patterns (currency, percentages, etc.)
    final numberRegex = RegExp(r'\b\d+(?:,\d{3})*(?:\.\d{2})?\s*(?:\$|€|£|¥|%|USD|EUR|GBP|JPY)\b');
    final numbersFound = numberRegex.allMatches(text);
    for (final match in numbersFound) {
      numberPatterns.add(match.group(0)!);
    }

    // Split text into segments
    var remainingText = text;
    var position = 0;

    for (final placeholder in placeholders) {
      final index = remainingText.indexOf(placeholder);
      if (index != -1) {
        // Add text before placeholder
        if (index > 0) {
          segments.add(remainingText.substring(0, index));
        }
        // Add placeholder
        segments.add(placeholder);
        // Update remaining text
        remainingText = remainingText.substring(index + placeholder.length);
        position += index + placeholder.length;
      }
    }

    // Add remaining text
    if (remainingText.isNotEmpty) {
      segments.add(remainingText);
    }

    return ComplexString._(
      originalText: text,
      placeholders: placeholders,
      datePatterns: datePatterns,
      numberPatterns: numberPatterns,
      segments: segments,
    );
  }

  const ComplexString._({
    required this.originalText,
    required this.placeholders,
    required this.datePatterns,
    required this.numberPatterns,
    required this.segments,
  });

  /// Original text.
  final String originalText;

  /// List of placeholders found.
  final List<String> placeholders;

  /// List of date patterns found.
  final List<String> datePatterns;

  /// List of number/currency patterns found.
  final List<String> numberPatterns;

  /// Text segments split by placeholders.
  final List<String> segments;

  /// Whether this string contains complex elements.
  bool get isComplex =>
      placeholders.isNotEmpty ||
      datePatterns.isNotEmpty ||
      numberPatterns.isNotEmpty;

  /// Gets translatable segments (excluding placeholders).
  List<String> get translatableSegments {
    return segments.where((segment) => !placeholders.contains(segment)).toList();
  }

  /// Reconstructs text with translated segments.
  String reconstruct(List<String> translatedSegments) {
    if (translatedSegments.length != translatableSegments.length) {
      throw ArgumentError('Translated segments count mismatch');
    }

    final result = <String>[];
    var translatableIndex = 0;

    for (final segment in segments) {
      if (placeholders.contains(segment)) {
        result.add(segment);
      } else {
        result.add(translatedSegments[translatableIndex]);
        translatableIndex++;
      }
    }

    return result.join();
  }
}

/// Processor for handling complex strings in translations.
class ComplexStringProcessor {
  /// Creates a [ComplexStringProcessor] with the given logger.
  ComplexStringProcessor(this.logger);

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Processes a string before translation (extracts complex elements).
  ProcessingResult preprocess(String text) {
    final complexString = ComplexString.parse(text);

    if (!complexString.isComplex) {
      return ProcessingResult(
        originalText: text,
        processedText: text,
        complexString: null,
        needsSpecialHandling: false,
      );
    }

    // Replace complex elements with placeholders for translation
    var processedText = text;

    // Replace dates with placeholders
    for (var i = 0; i < complexString.datePatterns.length; i++) {
      final datePattern = complexString.datePatterns[i];
      final placeholder = '{{DATE_$i}}';
      processedText = processedText.replaceFirst(datePattern, placeholder);
    }

    // Replace numbers/currency with placeholders
    for (var i = 0; i < complexString.numberPatterns.length; i++) {
      final numberPattern = complexString.numberPatterns[i];
      final placeholder = '{{NUMBER_$i}}';
      processedText = processedText.replaceFirst(numberPattern, placeholder);
    }

    return ProcessingResult(
      originalText: text,
      processedText: processedText,
      complexString: complexString,
      needsSpecialHandling: true,
    );
  }

  /// Processes a translated string (restores complex elements).
  String postprocess(String translatedText, ProcessingResult processingResult) {
    if (!processingResult.needsSpecialHandling || processingResult.complexString == null) {
      return translatedText;
    }

    var result = translatedText;

    // Restore dates (keep original format)
    for (var i = 0; i < processingResult.complexString!.datePatterns.length; i++) {
      final placeholder = '{{DATE_$i}}';
      final originalDate = processingResult.complexString!.datePatterns[i];
      result = result.replaceFirst(placeholder, originalDate);
    }

    // Restore numbers/currency (keep original format)
    for (var i = 0; i < processingResult.complexString!.numberPatterns.length; i++) {
      final placeholder = '{{NUMBER_$i}}';
      final originalNumber = processingResult.complexString!.numberPatterns[i];
      result = result.replaceFirst(placeholder, originalNumber);
    }

    return result;
  }

  /// Handles pluralization patterns in translations.
  PluralizationResult processPluralization(
    String sourceText,
    String translatedText,
    String sourceLang,
    String targetLang,
  ) {
    // Detect pluralization patterns
    final pluralPatterns = _detectPluralPatterns(sourceText, sourceLang);
    final translatedPatterns = _detectPluralPatterns(translatedText, targetLang);

    if (pluralPatterns.isEmpty && translatedPatterns.isEmpty) {
      return PluralizationResult(
        originalText: sourceText,
        translatedText: translatedText,
        pluralForms: {},
        isPluralized: false,
      );
    }

    // Validate pluralization consistency
    final issues = <String>[];

    if (pluralPatterns.length != translatedPatterns.length) {
      issues.add('Plural form count mismatch: ${pluralPatterns.length} vs ${translatedPatterns.length}');
    }

    // Check for ICU message format patterns
    final icuPattern = RegExp(r'\{[^}]*, plural, (.+)\}');
    final sourceIcuMatch = icuPattern.firstMatch(sourceText);
    final targetIcuMatch = icuPattern.firstMatch(translatedText);

    if ((sourceIcuMatch != null) != (targetIcuMatch != null)) {
      issues.add('ICU plural format inconsistency');
    }

    return PluralizationResult(
      originalText: sourceText,
      translatedText: translatedText,
      pluralForms: {
        'source': pluralPatterns,
        'target': translatedPatterns,
      },
      isPluralized: pluralPatterns.isNotEmpty || translatedPatterns.isNotEmpty,
      issues: issues,
    );
  }

  /// Detects pluralization patterns in text.
  List<String> _detectPluralPatterns(String text, String language) {
    final patterns = <String>[];

    // Common pluralization indicators
    final pluralIndicators = [
      // ICU MessageFormat
      RegExp(r'\{[^}]*, plural, (.+)\}'),

      // English patterns
      if (language.startsWith('en')) ...[
        RegExp(r'\b(?:is|are|was|were|has|have|does|do)\b', caseSensitive: false),
        RegExp(r'\b(?:this|these|that|those)\b', caseSensitive: false),
        RegExp(r'\b(?:one|two|few|many|other)\b', caseSensitive: false),
      ],

      // General patterns
      RegExp(r'\b\d+\s+(?:items?|things?|people?|users?)\b', caseSensitive: false),
      RegExp(r'\b(?:no|one|two|three|several|many|few)\s+\w+\b', caseSensitive: false),
    ];

    for (final indicator in pluralIndicators) {
      final matches = indicator.allMatches(text);
      for (final match in matches) {
        patterns.add(match.group(0)!);
      }
    }

    return patterns.toSet().toList(); // Remove duplicates
  }
}

/// Result of string preprocessing.
class ProcessingResult {
  /// Creates a [ProcessingResult] with the given parameters.
  const ProcessingResult({
    required this.originalText,
    required this.processedText,
    required this.complexString,
    required this.needsSpecialHandling,
  });

  /// Original input text.
  final String originalText;

  /// Processed text ready for translation.
  final String processedText;

  /// Complex string analysis (null if not complex).
  final ComplexString? complexString;

  /// Whether special handling is needed.
  final bool needsSpecialHandling;
}

/// Result of pluralization processing.
class PluralizationResult {
  /// Creates a [PluralizationResult] with the given parameters.
  const PluralizationResult({
    required this.originalText,
    required this.translatedText,
    required this.pluralForms,
    required this.isPluralized,
    this.issues = const [],
  });

  /// Original source text.
  final String originalText;

  /// Translated text.
  final String translatedText;

  /// Plural forms found in both languages.
  final Map<String, List<String>> pluralForms;

  /// Whether the text contains pluralization.
  final bool isPluralized;

  /// List of issues found.
  final List<String> issues;

  /// Whether there are any issues.
  bool get hasIssues => issues.isNotEmpty;
}
