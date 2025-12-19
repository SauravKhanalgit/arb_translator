import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:collection/collection.dart';

/// Represents a term in the terminology database.
class TermEntry {
  /// Creates a [TermEntry] with the given parameters.
  const TermEntry({
    required this.sourceTerm,
    required this.translations,
    required this.category,
    this.description,
    this.priority = TermPriority.medium,
    this.created = true,
    this.lastModified,
    this.usageCount = 0,
    this.tags = const [],
    this.context,
  });

  /// The source term in the base language.
  final String sourceTerm;

  /// Translations for different languages.
  final Map<String, String> translations;

  /// Category of the term (brand, technical, legal, etc.).
  final String category;

  /// Optional description or notes.
  final String? description;

  /// Priority level for this term.
  final TermPriority priority;

  /// Whether this term is approved/created by human.
  final bool created;

  /// Last modification timestamp.
  final DateTime? lastModified;

  /// How many times this term has been used.
  final int usageCount;

  /// Tags for organization and filtering.
  final List<String> tags;

  /// Optional context or usage examples.
  final String? context;

  /// Get translation for a specific language.
  String? getTranslation(String languageCode) => translations[languageCode];

  /// Check if term has translation for language.
  bool hasTranslation(String languageCode) => translations.containsKey(languageCode);

  /// Create a copy with updated translations.
  TermEntry withTranslation(String languageCode, String translation) {
    final newTranslations = Map<String, String>.from(translations);
    newTranslations[languageCode] = translation;

    return TermEntry(
      sourceTerm: sourceTerm,
      translations: newTranslations,
      category: category,
      description: description,
      priority: priority,
      created: created,
      lastModified: DateTime.now(),
      usageCount: usageCount + 1,
      tags: tags,
      context: context,
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() => {
    'sourceTerm': sourceTerm,
    'translations': translations,
    'category': category,
    'description': description,
    'priority': priority.name,
    'created': created,
    'lastModified': lastModified?.toIso8601String(),
    'usageCount': usageCount,
    'tags': tags,
    'context': context,
  };

  /// Create from JSON.
  factory TermEntry.fromJson(Map<String, dynamic> json) => TermEntry(
    sourceTerm: json['sourceTerm'],
    translations: Map<String, String>.from(json['translations'] ?? {}),
    category: json['category'] ?? 'general',
    description: json['description'],
    priority: TermPriority.values.firstWhere(
      (p) => p.name == json['priority'],
      orElse: () => TermPriority.medium,
    ),
    created: json['created'] ?? false,
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    usageCount: json['usageCount'] ?? 0,
    tags: List<String>.from(json['tags'] ?? []),
    context: json['context'],
  );

  @override
  String toString() => 'TermEntry($sourceTerm: ${translations.length} translations)';
}

/// Priority levels for terminology terms.
enum TermPriority {
  /// Low priority terms.
  low('Low'),

  /// Medium priority terms (default).
  medium('Medium'),

  /// High priority terms (brand names, key terms).
  high('High'),

  /// Critical terms (must be translated correctly).
  critical('Critical');

  const TermPriority(this.displayName);
  final String displayName;
}

/// Result of terminology lookup.
class TerminologyLookupResult {
  /// Creates a [TerminologyLookupResult] with the given parameters.
  const TerminologyLookupResult({
    required this.found,
    this.term,
    this.suggestions = const [],
    this.confidence = 0.0,
  });

  /// Whether an exact match was found.
  final bool found;

  /// The matching term entry (if found).
  final TermEntry? term;

  /// Alternative suggestions if no exact match.
  final List<TermEntry> suggestions;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Get the best translation for the given language.
  String? getTranslation(String languageCode) {
    if (term != null && term!.hasTranslation(languageCode)) {
      return term!.getTranslation(languageCode);
    }

    // Try suggestions
    for (final suggestion in suggestions) {
      if (suggestion.hasTranslation(languageCode)) {
        return suggestion.getTranslation(languageCode);
      }
    }

    return null;
  }
}

/// Advanced terminology management with glossary synchronization.
class TerminologyManager {
  /// Creates a [TerminologyManager] with the given storage path.
  TerminologyManager({
    required this.storagePath,
    required this.logger,
  }) {
    _loadFromDisk();
  }

  /// Path to store terminology data.
  final String storagePath;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Terminology database (source term → entry).
  final Map<String, TermEntry> _terms = {};

  /// Reverse index (translation → source term) for lookup.
  final Map<String, Map<String, String>> _reverseIndex = {};

  /// Category index for organization.
  final Map<String, List<String>> _categoryIndex = {};

  /// Synchronization configuration.
  final Map<String, dynamic> _syncConfig = {};

  /// Get all terms.
  Map<String, TermEntry> get terms => Map.unmodifiable(_terms);

  /// Get terms by category.
  Map<String, List<String>> get categories => Map.unmodifiable(_categoryIndex);

  /// Add or update a term in the terminology database.
  void addTerm(TermEntry term) {
    final key = term.sourceTerm.toLowerCase();
    _terms[key] = term;

    // Update reverse index
    _updateReverseIndex(term);

    // Update category index
    _categoryIndex.putIfAbsent(term.category, () => []).add(term.sourceTerm);

    logger.debug('Added term: ${term.sourceTerm} (${term.translations.length} translations)');
  }

  /// Remove a term from the database.
  bool removeTerm(String sourceTerm) {
    final key = sourceTerm.toLowerCase();
    final term = _terms.remove(key);

    if (term != null) {
      // Remove from reverse index
      for (final translation in term.translations.values) {
        _reverseIndex[translation.toLowerCase()]?.remove(sourceTerm);
      }

      // Remove from category index
      _categoryIndex[term.category]?.remove(sourceTerm);

      logger.debug('Removed term: $sourceTerm');
      return true;
    }

    return false;
  }

  /// Lookup a term in the database.
  TerminologyLookupResult lookupTerm(String text, String? sourceLang, String? targetLang) {
    final normalizedText = text.toLowerCase().trim();

    // Exact match
    final exactTerm = _terms[normalizedText];
    if (exactTerm != null) {
      return TerminologyLookupResult(
        found: true,
        term: exactTerm,
        confidence: 1.0,
      );
    }

    // Partial match (for compound terms)
    final partialMatches = <TermEntry>[];
    for (final term in _terms.values) {
      if (normalizedText.contains(term.sourceTerm.toLowerCase()) ||
          term.sourceTerm.toLowerCase().contains(normalizedText)) {
        partialMatches.add(term);
      }
    }

    if (partialMatches.isNotEmpty) {
      return TerminologyLookupResult(
        found: false,
        suggestions: partialMatches.take(3).toList(),
        confidence: 0.7,
      );
    }

    // Fuzzy match using reverse index
    final reverseMatches = <TermEntry>[];
    for (final entry in _reverseIndex.entries) {
      if (entry.key.contains(normalizedText)) {
        for (final sourceTerm in entry.value.keys) {
          final term = _terms[sourceTerm.toLowerCase()];
          if (term != null && !reverseMatches.contains(term)) {
            reverseMatches.add(term);
          }
        }
      }
    }

    return TerminologyLookupResult(
      found: false,
      suggestions: reverseMatches.take(3).toList(),
      confidence: reverseMatches.isNotEmpty ? 0.5 : 0.0,
    );
  }

  /// Apply terminology to a translation.
  String applyTerminology(String translatedText, String targetLang) {
    var result = translatedText;

    // Find and replace terms in the translated text
    for (final term in _terms.values) {
      final translation = term.getTranslation(targetLang);
      if (translation != null) {
        // Case-insensitive replacement to preserve original casing
        final sourcePattern = RegExp.escape(term.sourceTerm);
        final regex = RegExp(sourcePattern, caseSensitive: false);
        result = result.replaceAll(regex, translation);
      }
    }

    return result;
  }

  /// Import terminology from various formats.
  Future<void> importTerminology(String filePath, String format) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Terminology file not found', filePath);
    }

    final content = await file.readAsString();

    switch (format.toLowerCase()) {
      case 'json':
        await _importFromJson(content);
        break;
      case 'csv':
        await _importFromCsv(content);
        break;
      case 'yaml':
        await _importFromYaml(content);
        break;
      default:
        throw UnsupportedError('Unsupported terminology format: $format');
    }

    logger.info('Imported terminology from $filePath (${_terms.length} terms)');
  }

  /// Export terminology to various formats.
  Future<void> exportTerminology(String filePath, String format) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    String content;
    switch (format.toLowerCase()) {
      case 'json':
        content = _exportToJson();
        break;
      case 'csv':
        content = _exportToCsv();
        break;
      default:
        throw UnsupportedError('Unsupported export format: $format');
    }

    await file.writeAsString(content);
    logger.info('Exported terminology to $filePath (${_terms.length} terms)');
  }

  /// Synchronize terminology with external sources.
  Future<void> synchronize() async {
    // This would implement synchronization with external terminology services
    // For now, it's a placeholder for future implementation
    logger.info('Terminology synchronization not yet implemented');
  }

  /// Get terminology statistics.
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{
      'totalTerms': _terms.length,
      'categories': <String, int>{},
      'languages': <String, int>{},
      'priorityDistribution': <String, int>{},
    };

    // Category stats
    for (final entry in _categoryIndex.entries) {
      stats['categories'][entry.key] = entry.value.length;
    }

    // Language coverage
    final languageCoverage = <String, int>{};
    for (final term in _terms.values) {
      for (final lang in term.translations.keys) {
        languageCoverage[lang] = (languageCoverage[lang] ?? 0) + 1;
      }
    }
    stats['languages'] = languageCoverage;

    // Priority distribution
    for (final term in _terms.values) {
      final priority = term.priority.name;
      stats['priorityDistribution'][priority] =
          (stats['priorityDistribution'][priority] ?? 0) + 1;
    }

    return stats;
  }

  /// Save terminology to disk.
  Future<void> saveToDisk() async {
    try {
      final file = File(storagePath);
      await file.parent.create(recursive: true);

      final data = {
        'version': '1.0',
        'terms': _terms.values.map((t) => t.toJson()).toList(),
        'syncConfig': _syncConfig,
      };

      await file.writeAsString(json.encode(data));
      logger.debug('Terminology saved to disk (${_terms.length} terms)');
    } catch (e) {
      logger.error('Failed to save terminology', e);
    }
  }

  /// Load terminology from disk.
  Future<void> _loadFromDisk() async {
    try {
      final file = File(storagePath);
      if (!await file.exists()) {
        logger.debug('Terminology file not found, starting fresh');
        return;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      final termsData = data['terms'] as List<dynamic>;
      for (final termJson in termsData) {
        final term = TermEntry.fromJson(termJson);
        addTerm(term);
      }

      logger.info('Loaded ${_terms.length} terms from disk');
    } catch (e) {
      logger.warning('Failed to load terminology from disk, starting fresh: $e');
    }
  }

  /// Update the reverse index for a term.
  void _updateReverseIndex(TermEntry term) {
    // Clear old entries for this term
    for (final translation in term.translations.values) {
      _reverseIndex[translation.toLowerCase()]?.remove(term.sourceTerm);
    }

    // Add new entries
    for (final translation in term.translations.values) {
      _reverseIndex.putIfAbsent(translation.toLowerCase(), () => {})[term.sourceTerm] = term.sourceTerm;
    }
  }

  /// Import from JSON format.
  Future<void> _importFromJson(String content) async {
    final data = json.decode(content) as Map<String, dynamic>;
    final terms = data['terms'] as List<dynamic>;

    for (final termJson in terms) {
      final term = TermEntry.fromJson(termJson);
      addTerm(term);
    }
  }

  /// Import from CSV format.
  Future<void> _importFromCsv(String content) async {
    final lines = content.split('\n');
    if (lines.isEmpty) return;

    final headers = _parseCsvLine(lines.first);
    final termIndex = headers.indexOf('term');
    final categoryIndex = headers.indexOf('category');

    if (termIndex == -1) {
      throw FormatException('CSV must have a "term" column');
    }

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = _parseCsvLine(lines[i]);
      if (values.length > termIndex) {
        final sourceTerm = values[termIndex];
        final category = categoryIndex != -1 && values.length > categoryIndex
            ? values[categoryIndex]
            : 'imported';

        final translations = <String, String>{};

        // Add translations for other columns
        for (var j = 0; j < headers.length && j < values.length; j++) {
          if (j != termIndex && j != categoryIndex && values[j].isNotEmpty) {
            final lang = headers[j];
            translations[lang] = values[j];
          }
        }

        if (translations.isNotEmpty) {
          final term = TermEntry(
            sourceTerm: sourceTerm,
            translations: translations,
            category: category,
            created: true,
            lastModified: DateTime.now(),
          );
          addTerm(term);
        }
      }
    }
  }

  /// Import from YAML format.
  Future<void> _importFromYaml(String content) async {
    // Simple YAML parsing (could be enhanced with yaml package)
    final lines = content.split('\n');
    final terms = <Map<String, dynamic>>[];

    var currentTerm = <String, dynamic>{};
    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('  ')) {
        // Indented line (translation)
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
          final lang = line.substring(0, colonIndex).trim();
          final translation = line.substring(colonIndex + 1).trim();
          if (translation.startsWith('"') && translation.endsWith('"')) {
            currentTerm[lang] = translation.substring(1, translation.length - 1);
          } else {
            currentTerm[lang] = translation;
          }
        }
      } else if (line.contains(':')) {
        // New term
        if (currentTerm.isNotEmpty) {
          terms.add(currentTerm);
        }

        final colonIndex = line.indexOf(':');
        final termName = line.substring(0, colonIndex).trim();
        currentTerm = {'term': termName, 'category': 'imported'};
      }
    }

    if (currentTerm.isNotEmpty) {
      terms.add(currentTerm);
    }

    // Convert to TermEntry objects
    for (final termData in terms) {
      final sourceTerm = termData['term'] as String;
      final category = termData['category'] as String? ?? 'imported';
      final translations = <String, String>{};

      termData.forEach((key, value) {
        if (key != 'term' && key != 'category' && value is String) {
          translations[key] = value;
        }
      });

      if (translations.isNotEmpty) {
        final term = TermEntry(
          sourceTerm: sourceTerm,
          translations: translations,
          category: category,
          created: true,
          lastModified: DateTime.now(),
        );
        addTerm(term);
      }
    }
  }

  /// Export to JSON format.
  String _exportToJson() {
    final data = {
      'exported': DateTime.now().toIso8601String(),
      'terms': _terms.values.map((t) => t.toJson()).toList(),
    };
    return json.encode(data);
  }

  /// Export to CSV format.
  String _exportToCsv() {
    if (_terms.isEmpty) return '';

    // Collect all languages
    final allLanguages = <String>{};
    for (final term in _terms.values) {
      allLanguages.addAll(term.translations.keys);
    }
    final languages = allLanguages.toList()..sort();

    final buffer = StringBuffer();
    buffer.writeln(['term', 'category', ...languages].join(','));

    for (final term in _terms.values) {
      final row = [term.sourceTerm, term.category];

      for (final lang in languages) {
        final translation = term.getTranslation(lang) ?? '';
        row.add(_escapeCsvField(translation));
      }

      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Parse CSV line handling quoted fields.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }

    result.add(current);
    return result;
  }

  /// Escape CSV field.
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}

/// Integration utilities for terminology in translation workflows.
class TerminologyIntegration {
  /// Creates a [TerminologyIntegration] with the given manager.
  TerminologyIntegration(this.manager, this.logger);

  /// Terminology manager.
  final TerminologyManager manager;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Apply terminology to ARB content during translation.
  Future<Map<String, dynamic>> applyToArbContent(
    Map<String, dynamic> arbContent,
    String targetLang,
  ) async {
    final processedContent = Map<String, dynamic>.from(arbContent);

    for (final entry in arbContent.entries) {
      if (entry.key.startsWith('@')) continue; // Skip metadata

      final value = entry.value?.toString();
      if (value == null || value.isEmpty) continue;

      // Apply terminology to the text
      final processedValue = manager.applyTerminology(value, targetLang);

      if (processedValue != value) {
        processedContent[entry.key] = processedValue;
        logger.debug('Applied terminology to ${entry.key}');
      }
    }

    return processedContent;
  }

  /// Validate terminology consistency in ARB files.
  Future<List<String>> validateTerminologyConsistency(
    Map<String, Map<String, dynamic>> arbFiles,
  ) async {
    final issues = <String>[];

    for (final entry in arbFiles.entries) {
      final locale = entry.key;
      final content = entry.value;

      for (final contentEntry in content.entries) {
        if (contentEntry.key.startsWith('@')) continue;

        final text = contentEntry.value?.toString() ?? '';
        final result = manager.lookupTerm(text, 'en', locale);

        if (result.found && result.term != null) {
          // Check if the translation matches the approved term
          final approvedTranslation = result.term!.getTranslation(locale);
          if (approvedTranslation != null && approvedTranslation != text) {
            issues.add(
              '$locale:${contentEntry.key}: Translation "$text" does not match '
              'approved terminology "$approvedTranslation"'
            );
          }
        }
      }
    }

    return issues;
  }

  /// Extract potential terminology from ARB files.
  Future<List<TermEntry>> extractPotentialTerms(
    Map<String, Map<String, dynamic>> arbFiles, {
    int minOccurrences = 2,
    List<String> categories = const ['brand', 'technical', 'legal'],
  }) async {
    final termCandidates = <String, Map<String, dynamic>>{};

    // Analyze all files to find repeated terms
    for (final entry in arbFiles.entries) {
      final locale = entry.key;
      final content = entry.value;

      for (final contentEntry in content.entries) {
        if (contentEntry.key.startsWith('@')) continue;

        final text = contentEntry.value?.toString() ?? '';
        final words = text.split(RegExp(r'\s+')).where((w) => w.length > 3);

        for (final word in words) {
          final normalized = word.toLowerCase();
          termCandidates.putIfAbsent(normalized, () => {
            'term': word,
            'occurrences': <String, int>{},
            'locales': <String>{},
          });

          termCandidates[normalized]!['occurrences'][locale] =
              (termCandidates[normalized]!['occurrences'][locale] ?? 0) + 1;
          (termCandidates[normalized]!['locales'] as Set<String>).add(locale);
        }
      }
    }

    // Filter candidates based on criteria
    final potentialTerms = <TermEntry>[];

    for (final candidate in termCandidates.values) {
      final occurrences = candidate['occurrences'] as Map<String, int>;
      final totalOccurrences = occurrences.values.reduce((a, b) => a + b);
      final locales = candidate['locales'] as Set<String>;

      if (totalOccurrences >= minOccurrences && locales.length >= 2) {
        // Create term entry
        final term = candidate['term'] as String;
        final translations = <String, String>{};

        // Add translations from different locales
        for (final locale in locales) {
          if (locale != 'en') { // Assume 'en' is source
            translations[locale] = term; // Placeholder - would need proper extraction
          }
        }

        potentialTerms.add(TermEntry(
          sourceTerm: term,
          translations: translations,
          category: 'extracted',
          description: 'Automatically extracted from ARB files',
          priority: TermPriority.low,
          created: false, // Needs human review
          lastModified: DateTime.now(),
          usageCount: totalOccurrences,
        ));
      }
    }

    return potentialTerms;
  }
}
