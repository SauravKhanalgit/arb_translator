import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:crypto/crypto.dart';

/// Translation memory entry with metadata.
class TranslationEntry {
  /// Creates a [TranslationEntry] with the given parameters.
  const TranslationEntry({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.provider,
    required this.qualityScore,
    required this.timestamp,
    this.context,
    this.projectId,
    this.userId,
    this.tags = const [],
  });

  /// Source text to translate.
  final String sourceText;

  /// Translated text.
  final String translatedText;

  /// Source language code.
  final String sourceLang;

  /// Target language code.
  final String targetLang;

  /// Translation provider used.
  final String provider;

  /// Quality score (0.0 to 1.0).
  final double qualityScore;

  /// Timestamp when translation was created.
  final DateTime timestamp;

  /// Optional context information.
  final Map<String, dynamic>? context;

  /// Optional project identifier.
  final String? projectId;

  /// Optional user identifier.
  final String? userId;

  /// Optional tags for categorization.
  final List<String> tags;

  /// Unique hash of the source text for quick lookup.
  String get sourceHash => sha256.convert(utf8.encode(sourceText)).toString();

  /// Composite key combining source, target, and context.
  String get compositeKey {
    final contextStr = context != null ? json.encode(context) : '';
    return '$sourceHash:$sourceLang:$targetLang:$contextStr';
  }

  /// Creates a copy with updated fields.
  TranslationEntry copyWith({
    String? translatedText,
    String? provider,
    double? qualityScore,
    Map<String, dynamic>? context,
    List<String>? tags,
  }) {
    return TranslationEntry(
      sourceText: sourceText,
      translatedText: translatedText ?? this.translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
      provider: provider ?? this.provider,
      qualityScore: qualityScore ?? this.qualityScore,
      timestamp: DateTime.now(),
      context: context ?? this.context,
      projectId: projectId,
      userId: userId,
      tags: tags ?? this.tags,
    );
  }

  /// Converts to JSON for storage.
  Map<String, dynamic> toJson() => {
        'sourceText': sourceText,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'provider': provider,
        'qualityScore': qualityScore,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
        'projectId': projectId,
        'userId': userId,
        'tags': tags,
      };

  /// Creates from JSON.
  factory TranslationEntry.fromJson(Map<String, dynamic> json) =>
      TranslationEntry(
        sourceText: json['sourceText'] as String,
        translatedText: json['translatedText'] as String,
        sourceLang: json['sourceLang'] as String,
        targetLang: json['targetLang'] as String,
        provider: json['provider'] as String,
        qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.8,
        timestamp: DateTime.parse(json['timestamp'] as String),
        context: json['context'] as Map<String, dynamic>?,
        projectId: json['projectId'] as String?,
        userId: json['userId'] as String?,
        tags: List<String>.from(json['tags'] as Iterable? ?? []),
      );

  @override
  String toString() =>
      'TranslationEntry($sourceLang → $targetLang: ${sourceText.length} chars)';
}

/// Fuzzy matching result.
class FuzzyMatch {
  /// Creates a [FuzzyMatch] with the given parameters.
  const FuzzyMatch({
    required this.entry,
    required this.similarityScore,
    required this.matchType,
  });

  /// The matching translation entry.
  final TranslationEntry entry;

  /// Similarity score (0.0 to 1.0).
  final double similarityScore;

  /// Type of match (exact, fuzzy, contextual).
  final MatchType matchType;

  /// Whether this is a high-confidence match.
  bool get isHighConfidence => similarityScore >= 0.9;

  /// Whether this is acceptable for reuse.
  bool get isAcceptable => similarityScore >= 0.7;
}

/// Types of fuzzy matches.
enum MatchType {
  /// Exact match (100% identical).
  exact('Exact Match'),

  /// Fuzzy match based on text similarity.
  fuzzy('Fuzzy Match'),

  /// Contextual match (similar context).
  contextual('Contextual Match'),

  /// Term-based match (matching key terms).
  term('Term Match');

  const MatchType(this.displayName);
  final String displayName;
}

/// Advanced translation memory with fuzzy matching and learning capabilities.
class TranslationMemory {
  /// Creates a [TranslationMemory] with the given storage path.
  TranslationMemory({
    required this.storagePath,
    required this.logger,
    this.maxEntries = 10000,
    this.autoSaveInterval = const Duration(minutes: 5),
  }) {
    _loadFromDisk();
    _startAutoSave();
  }

  /// Path to store translation memory data.
  final String storagePath;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Maximum number of entries to store.
  final int maxEntries;

  /// Auto-save interval.
  final Duration autoSaveInterval;

  /// In-memory storage of translation entries.
  final Map<String, TranslationEntry> _entries = {};

  /// Index for fuzzy matching (source hash → entries).
  final Map<String, List<String>> _fuzzyIndex = {};

  /// Term index for keyword-based matching.
  final Map<String, List<String>> _termIndex = {};

  /// Statistics tracking.
  final Map<String, dynamic> _stats = {
    'totalEntries': 0,
    'cacheHits': 0,
    'cacheMisses': 0,
    'fuzzyMatches': 0,
    'autoSaves': 0,
  };

  /// Adds a translation entry to memory.
  void addEntry(TranslationEntry entry) {
    final key = entry.compositeKey;

    // Check if we already have this exact translation
    if (_entries.containsKey(key)) {
      final existing = _entries[key]!;
      // Keep the higher quality translation
      if (entry.qualityScore > existing.qualityScore) {
        _entries[key] = entry;
      }
    } else {
      _entries[key] = entry;

      // Maintain size limits (keep highest quality entries)
      if (_entries.length > maxEntries) {
        _evictLowQualityEntries();
      }
    }

    // Update indexes
    _updateIndexes(entry);

    _stats['totalEntries'] = _entries.length;
    logger.debug(
        'Added translation to memory: ${entry.sourceLang} → ${entry.targetLang}');
  }

  /// Finds exact match for the given text and language pair.
  TranslationEntry? findExactMatch(
    String sourceText,
    String sourceLang,
    String targetLang, {
    Map<String, dynamic>? context,
  }) {
    final contextStr = context != null ? json.encode(context) : '';
    final sourceHash = sha256.convert(utf8.encode(sourceText)).toString();
    final key = '$sourceHash:$sourceLang:$targetLang:$contextStr';

    final entry = _entries[key];
    if (entry != null) {
      _stats['cacheHits'] = (_stats['cacheHits'] as int) + 1;
      logger.debug('Cache hit: exact match found');
    } else {
      _stats['cacheMisses'] = (_stats['cacheMisses'] as int) + 1;
    }

    return entry;
  }

  /// Finds fuzzy matches for the given text.
  List<FuzzyMatch> findFuzzyMatches(
    String sourceText,
    String sourceLang,
    String targetLang, {
    Map<String, dynamic>? context,
    int maxResults = 5,
    double minSimilarity = 0.6,
  }) {
    final matches = <FuzzyMatch>[];

    // Search through all entries for the target language pair
    for (final entry in _entries.values) {
      if (entry.sourceLang != sourceLang || entry.targetLang != targetLang) {
        continue;
      }

      final similarity = _calculateSimilarity(
          sourceText, entry.sourceText, context, entry.context);
      if (similarity >= minSimilarity) {
        final matchType = _determineMatchType(
            sourceText, entry.sourceText, context, entry.context);

        matches.add(FuzzyMatch(
          entry: entry,
          similarityScore: similarity,
          matchType: matchType,
        ));
      }
    }

    // Sort by similarity score (highest first)
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    // Limit results
    final results = matches.take(maxResults).toList();

    if (results.isNotEmpty) {
      _stats['fuzzyMatches'] = (_stats['fuzzyMatches'] as int) + 1;
      logger.debug(
          'Found ${results.length} fuzzy matches (best: ${(results.first.similarityScore * 100).round()}%)');
    }

    return results;
  }

  /// Suggests translation based on memory (exact or fuzzy match).
  String? suggestTranslation(
    String sourceText,
    String sourceLang,
    String targetLang, {
    Map<String, dynamic>? context,
  }) {
    // Try exact match first
    final exactMatch =
        findExactMatch(sourceText, sourceLang, targetLang, context: context);
    if (exactMatch != null) {
      return exactMatch.translatedText;
    }

    // Try fuzzy matches
    final fuzzyMatches = findFuzzyMatches(
      sourceText,
      sourceLang,
      targetLang,
      context: context,
      maxResults: 3,
      minSimilarity: 0.8,
    );

    if (fuzzyMatches.isNotEmpty && fuzzyMatches.first.isAcceptable) {
      return fuzzyMatches.first.entry.translatedText;
    }

    return null;
  }

  /// Learns from a new translation by adding it to memory.
  void learnTranslation(
    String sourceText,
    String translatedText,
    String sourceLang,
    String targetLang,
    String provider, {
    double qualityScore = 0.8,
    Map<String, dynamic>? context,
    String? projectId,
    String? userId,
    List<String>? tags,
  }) {
    final entry = TranslationEntry(
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
      provider: provider,
      qualityScore: qualityScore,
      timestamp: DateTime.now(),
      context: context,
      projectId: projectId,
      userId: userId,
      tags: tags ?? [],
    );

    addEntry(entry);
  }

  /// Gets memory statistics.
  Map<String, dynamic> getStats() => Map.from(_stats);

  /// Clears all entries from memory.
  void clear() {
    _entries.clear();
    _fuzzyIndex.clear();
    _termIndex.clear();
    _stats['totalEntries'] = 0;
    _stats['cacheHits'] = 0;
    _stats['cacheMisses'] = 0;
    _stats['fuzzyMatches'] = 0;
    logger.info('Translation memory cleared');
  }

  /// Saves memory to disk.
  Future<void> saveToDisk() async {
    try {
      final file = File(storagePath);
      await file.parent.create(recursive: true);

      final data = {
        'version': '1.0',
        'stats': _stats,
        'entries': _entries.values.map((e) => e.toJson()).toList(),
      };

      await file.writeAsString(json.encode(data));
      _stats['autoSaves'] = (_stats['autoSaves'] as int) + 1;
      logger.debug(
          'Translation memory saved to disk (${_entries.length} entries)');
    } catch (e) {
      logger.error('Failed to save translation memory', e);
    }
  }

  /// Loads memory from disk.
  Future<void> _loadFromDisk() async {
    try {
      final file = File(storagePath);
      if (!await file.exists()) {
        logger.debug('Translation memory file not found, starting fresh');
        return;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      final entries = data['entries'] as List<dynamic>;
      for (final entryJson in entries) {
        final entry =
            TranslationEntry.fromJson(entryJson as Map<String, dynamic>);
        _entries[entry.compositeKey] = entry;
        _updateIndexes(entry);
      }

      // Load stats if available
      if (data.containsKey('stats')) {
        final savedStats = data['stats'] as Map<String, dynamic>;
        _stats.addAll(savedStats);
      }

      _stats['totalEntries'] = _entries.length;
      logger.info('Loaded ${_entries.length} translation entries from disk');
    } catch (e) {
      logger.warning(
          'Failed to load translation memory from disk, starting fresh: $e');
    }
  }

  /// Updates search indexes for the given entry.
  void _updateIndexes(TranslationEntry entry) {
    final sourceHash = entry.sourceHash;

    // Fuzzy index
    _fuzzyIndex.putIfAbsent(sourceHash, () => []).add(entry.compositeKey);

    // Term index (extract keywords)
    final terms = _extractTerms(entry.sourceText);
    for (final term in terms) {
      _termIndex.putIfAbsent(term, () => []).add(entry.compositeKey);
    }
  }

  /// Evicts low-quality entries when memory is full.
  void _evictLowQualityEntries() {
    if (_entries.isEmpty) return;

    // Sort entries by quality score (ascending)
    final sortedEntries = _entries.entries.toList()
      ..sort((a, b) => a.value.qualityScore.compareTo(b.value.qualityScore));

    // Remove the lowest quality entries
    final toRemove = (maxEntries * 0.1).round(); // Remove 10%
    for (var i = 0; i < toRemove && i < sortedEntries.length; i++) {
      _entries.remove(sortedEntries[i].key);
    }

    logger.debug('Evicted $toRemove low-quality entries from memory');
  }

  /// Calculates similarity between two texts with context awareness.
  double _calculateSimilarity(
    String text1,
    String text2,
    Map<String, dynamic>? context1,
    Map<String, dynamic>? context2,
  ) {
    // Text similarity (primary factor)
    final textSimilarity = _textSimilarity(text1, text2);

    // Context similarity (secondary factor)
    final contextSimilarity = _contextSimilarity(context1, context2);

    // Weighted combination
    return (textSimilarity * 0.8) + (contextSimilarity * 0.2);
  }

  /// Calculates basic text similarity.
  double _textSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Simple word-based similarity
    final aWords =
        a.toLowerCase().split(RegExp(r'[^\w]+')).where((w) => w.isNotEmpty);
    final bWords =
        b.toLowerCase().split(RegExp(r'[^\w]+')).where((w) => w.isNotEmpty);

    final aSet = aWords.toSet();
    final bSet = bWords.toSet();

    final intersection = aSet.intersection(bSet).length;
    final union = aSet.union(bSet).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Calculates context similarity.
  double _contextSimilarity(
      Map<String, dynamic>? context1, Map<String, dynamic>? context2) {
    if (context1 == null && context2 == null) return 1.0;
    if (context1 == null || context2 == null) return 0.5;

    // Simple key matching for now
    final keys1 = context1.keys.toSet();
    final keys2 = context2.keys.toSet();

    final intersection = keys1.intersection(keys2).length;
    final union = keys1.union(keys2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Determines the type of match between two texts.
  MatchType _determineMatchType(
    String text1,
    String text2,
    Map<String, dynamic>? context1,
    Map<String, dynamic>? context2,
  ) {
    if (text1 == text2) {
      return MatchType.exact;
    }

    // Check for contextual similarity
    if (context1 != null && context2 != null) {
      final contextSim = _contextSimilarity(context1, context2);
      if (contextSim > 0.8) {
        return MatchType.contextual;
      }
    }

    // Check for term-based similarity
    final terms1 = _extractTerms(text1).toSet();
    final terms2 = _extractTerms(text2).toSet();
    final termOverlap =
        terms1.intersection(terms2).length / max(terms1.length, terms2.length);

    if (termOverlap > 0.7) {
      return MatchType.term;
    }

    return MatchType.fuzzy;
  }

  /// Extracts meaningful terms from text for indexing.
  List<String> _extractTerms(String text) {
    // Simple term extraction (can be enhanced with NLP)
    return text
        .toLowerCase()
        .split(RegExp(r'[^\w]+'))
        .where((word) => word.length > 2)
        .toList();
  }

  /// Starts the auto-save timer.
  void _startAutoSave() {
    Future.delayed(autoSaveInterval, () async {
      await saveToDisk();
      _startAutoSave(); // Schedule next save
    });
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    await saveToDisk();
    logger.debug('Translation memory disposed');
  }
}
