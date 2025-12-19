import 'dart:convert';
import 'dart:io';

import 'package:arb_translator_gen_z/src/ai_providers/ai_provider_manager.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/exceptions/translation_exceptions.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:arb_translator_gen_z/src/string_processing/complex_string_processor.dart';
import 'package:arb_translator_gen_z/src/translation_memory/translation_memory.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

/// Enhanced translation service with retry logic, rate limiting, and comprehensive error handling.
///
/// This class provides robust translation capabilities using multiple translation APIs
/// with intelligent fallback mechanisms and rate limiting to prevent API abuse.
class TranslationService {
  /// Creates a [TranslationService] with the given [config].
  TranslationService(this._config) : _httpClient = http.Client() {
    _aiProviderManager = AIProviderManager(_config, _logger);
    _initializeTranslationMemory();
    _complexStringProcessor = ComplexStringProcessor(_logger);
  }

  final TranslatorConfig _config;
  final http.Client _httpClient;
  final TranslatorLogger _logger = TranslatorLogger();

  DateTime _lastRequestTime = DateTime(1970);

  /// AI provider manager for advanced translations.
  late final AIProviderManager _aiProviderManager;

  /// Translation memory for caching and fuzzy matching.
  late final TranslationMemory _translationMemory;

  /// Complex string processor for handling dates, numbers, plurals.
  late final ComplexStringProcessor _complexStringProcessor;

  /// Translates the given [text] into the specified [targetLang].
  ///
  /// Uses intelligent retry logic and rate limiting to ensure reliable translation.
  /// Supports multiple translation APIs with automatic fallback and context awareness.
  ///
  /// Example:
  /// ```dart
  /// final service = TranslationService(config);
  /// final translated = await service.translateText(
  ///   'Hello',
  ///   'es',
  ///   description: 'A greeting message',
  ///   keyName: 'greeting'
  /// );
  /// print(translated); // Hola
  /// ```
  ///
  /// [text]: The string to translate. Must not be empty or null.
  /// [targetLang]: The target language code (e.g., 'es' for Spanish).
  /// [sourceLang]: Optional source language code (defaults to auto-detect).
  /// [description]: Optional context description for better translation.
  /// [surroundingContext]: Optional map of surrounding strings for context.
  /// [keyName]: Optional translation key name for better context.
  ///
  /// Returns a [Future<String>] containing the translated text.
  ///
  /// Throws [InvalidTranslationTextException] if text is invalid.
  /// Throws [UnsupportedLanguageException] if target language is not supported.
  /// Throws [TranslationApiException] if all translation attempts fail.
  /// Throws [TranslationRateLimitException] if rate limit is exceeded.
  Future<String> translateText(
    String text,
    String targetLang, {
    String? sourceLang,
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  }) async {
    // Validate input
    _validateTranslationInput(text, targetLang);

    // Apply rate limiting
    await _applyRateLimit();

    // Use retry logic for robust translation
    const retryOptions = RetryOptions(maxAttempts: 3);

    try {
    return await retryOptions.retry(
      () => _performTranslation(text, targetLang, sourceLang,
          description: description, surroundingContext: surroundingContext, keyName: keyName),
      retryIf: _shouldRetry,
    );
    } catch (e) {
      _logger.error(
        'Translation failed after ${_config.retryAttempts} attempts',
        e,
      );

      if (e is TranslationException) {
        rethrow;
      } else {
        throw TranslationApiException(500, 'Unexpected error: $e');
      }
    }
  }

  /// Translates multiple texts concurrently with proper throttling.
  ///
  /// Automatically batches requests to respect rate limits and prevents
  /// overwhelming the translation API.
  ///
  /// [translations]: Map of key-value pairs to translate.
  /// [targetLang]: The target language code.
  /// [sourceLang]: Optional source language code.
  ///
  /// Returns a [Future<Map<String, String>>] with translated values.
  Future<Map<String, String>> translateBatch(
    Map<String, String> translations,
    String targetLang, {
    String? sourceLang,
  }) async {
    _logger.info(
      'Starting batch translation of ${translations.length} items to $targetLang',
    );

    final results = <String, String>{};
    final entries = translations.entries.toList();
    final batchSize = _config.maxConcurrentTranslations;

    // Process in batches to respect rate limits
    for (var i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize).toList();

      _logger.progress(
        'Translating batch ${(i ~/ batchSize) + 1} of ${(entries.length / batchSize).ceil()}',
      );

      final futures = batch.map((entry) async {
        try {
          final translated = await translateText(
            entry.value,
            targetLang,
            sourceLang: sourceLang,
          );
          return MapEntry(entry.key, translated);
        } catch (e) {
          _logger.warning('Failed to translate "${entry.key}": $e');
          return MapEntry(entry.key, entry.value); // Keep original on failure
        }
      });

      final batchResults = await Future.wait(futures);
      results.addEntries(batchResults);
    }

    _logger.success('Completed batch translation');
    return results;
  }

  /// Gets AI provider statistics and health information.
  Map<String, dynamic> getAIProviderStats() {
    return _aiProviderManager.getProviderStats();
  }

  /// Tests all AI providers to ensure they're working correctly.
  Future<Map<TranslationProvider, bool>> testAIProviders() async {
    return _aiProviderManager.testProviders();
  }

  /// Gets cost estimates for translating text with all available providers.
  Map<TranslationProvider, double> getCostEstimates(String text) {
    return _aiProviderManager.getCostEstimates(text);
  }

  /// Initializes the translation memory.
  void _initializeTranslationMemory() {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final memoryPath = path.join(homeDir, '.arb_translator', 'translation_memory.json');
    _translationMemory = TranslationMemory(
      storagePath: memoryPath,
      logger: _logger,
      maxEntries: 50000,
    );
  }

  /// Gets translation memory statistics.
  Map<String, dynamic> getMemoryStats() => _translationMemory.getStats();

  /// Gets AI provider statistics.

  /// Clears translation memory.
  void clearMemory() => _translationMemory.clear();

  /// Disposes of the HTTP client resources.
  Future<void> dispose() async {
    await _translationMemory.dispose();
    _httpClient.close();
  }

  Future<String> _performTranslation(
    String text,
    String targetLang,
    String? sourceLang, {
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  }) async {
    final source = sourceLang ?? _config.sourceLanguage;

    _logger.debug('Translating: "$text" ($source -> $targetLang)');

    // Preprocess complex strings
    final processingResult = _complexStringProcessor.preprocess(text);
    final textToTranslate = processingResult.processedText;

    // Prepare context for memory lookup
    final context = <String, dynamic>{};
    if (description != null) context['description'] = description;
    if (surroundingContext != null) context['surrounding'] = surroundingContext;
    if (keyName != null) context['keyName'] = keyName;
    if (processingResult.needsSpecialHandling) {
      context['complex'] = true;
    }

    // Try translation memory first (exact match)
    final memorySuggestion = _translationMemory.suggestTranslation(
      textToTranslate,
      source,
      targetLang,
      context: context.isNotEmpty ? context : null,
    );

    if (memorySuggestion != null) {
      _logger.debug('Translation memory hit - reusing cached translation');

      // Postprocess the result if needed
      if (processingResult.needsSpecialHandling) {
        final processedResult = ProcessingResult(
          originalText: memorySuggestion,
          processedText: memorySuggestion,
          complexString: processingResult.complexString,
          needsSpecialHandling: true,
        );
        return _complexStringProcessor.postprocess(memorySuggestion, processedResult);
      }

      return memorySuggestion;
    }

    // No memory match, perform actual translation
    String translatedText;
    String provider = 'unknown';
    double qualityScore = 0.8;

    // Try AI providers first if available and preferred
    if (_aiProviderManager.providers.isNotEmpty &&
        _config.aiModelConfig.preferredProvider != TranslationProvider.google) {
      try {
        final result = await _aiProviderManager.translate(
          text,
          source,
          targetLang,
          preferredProvider: _config.aiModelConfig.preferredProvider,
          description: description,
          surroundingContext: surroundingContext,
          keyName: keyName,
        );

        translatedText = result.text;
        provider = result.provider.name;
        qualityScore = result.qualityScore ?? 0.9; // AI translations are generally high quality

        _logger.debug('AI translation successful: ${result.provider.displayName}');
      } catch (e) {
        _logger.warning('AI translation failed, falling back to Google Translate: $e');
        // Fall through to Google Translate
        translatedText = await _translateWithGoogleApi(text, targetLang, source);
        provider = 'google';
      }
    } else {
      // Try custom API endpoint if configured
      if (_config.customApiEndpoint != null) {
        try {
          translatedText = await _translateWithCustomApi(text, targetLang, source);
          provider = 'custom';
        } catch (e) {
          _logger.warning('Custom API failed, falling back to Google Translate: $e');
          translatedText = await _translateWithGoogleApi(text, targetLang, source);
          provider = 'google';
        }
      } else {
        // Use Google Translate API as fallback
        translatedText = await _translateWithGoogleApi(text, targetLang, source);
        provider = 'google';
      }
    }

    // Postprocess complex strings if needed
    if (processingResult.needsSpecialHandling) {
      translatedText = _complexStringProcessor.postprocess(translatedText, processingResult);
      _logger.debug('Postprocessed complex string elements');
    }

    // Learn from this translation for future reuse (store processed version)
    _translationMemory.learnTranslation(
      textToTranslate,
      translatedText,
      source,
      targetLang,
      provider,
      qualityScore: qualityScore,
      context: context.isNotEmpty ? context : null,
    );

    return translatedText;
  }

  Future<String> _translateWithGoogleApi(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    final url = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t'
      '&q=${Uri.encodeComponent(text)}',
    );

    final response = await _httpClient
        .get(url)
        .timeout(Duration(milliseconds: _config.requestTimeoutMs));

    _lastRequestTime = DateTime.now();

    if (response.statusCode == 200) {
      try {
        final result = json.decode(response.body);

        // Handle different response formats
        if (result is List && result.isNotEmpty) {
          final translations = result[0];
          if (translations is List && translations.isNotEmpty) {
            final translatedText = translations[0][0] as String;
            _logger.debug('Translation successful: "$translatedText"');
            return translatedText;
          }
        }

        throw const TranslationApiException(200, 'Unexpected response format');
      } catch (e) {
        throw TranslationApiException(200, 'Failed to parse response: $e');
      }
    } else if (response.statusCode == 429) {
      // Rate limit exceeded
      final retryAfter = _parseRetryAfter(response.headers);
      throw TranslationRateLimitException(retryAfter);
    } else if (response.statusCode == 503) {
      // Service unavailable
      throw const TranslationServiceUnavailableException();
    } else {
      throw TranslationApiException(
        response.statusCode,
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
  }

  Future<String> _translateWithCustomApi(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    // Placeholder for custom API implementation
    // Users can extend this method to support their preferred translation API
    throw UnimplementedError('Custom API translation not implemented');
  }

  void _validateTranslationInput(String text, String targetLang) {
    if (text.trim().isEmpty) {
      throw const InvalidTranslationTextException('', 'Text cannot be empty');
    }

    if (text.length > 5000) {
      throw InvalidTranslationTextException(
        text,
        'Text too long (${text.length} characters, max 5000)',
      );
    }

    if (targetLang.trim().isEmpty) {
      throw UnsupportedLanguageException(targetLang);
    }
  }

  Future<void> _applyRateLimit() async {
    final now = DateTime.now();
    final timeSinceLastRequest =
        now.difference(_lastRequestTime).inMilliseconds;

    if (timeSinceLastRequest < _config.rateLimitDelayMs) {
      final delayNeeded = _config.rateLimitDelayMs - timeSinceLastRequest;
      _logger.debug('Rate limiting: waiting ${delayNeeded}ms');
      await Future<void>.delayed(Duration(milliseconds: delayNeeded));
    }
  }

  bool _shouldRetry(Exception e) {
    // Don't retry on validation errors or unsupported languages
    if (e is InvalidTranslationTextException ||
        e is UnsupportedLanguageException) {
      return false;
    }

    // Retry on network errors and temporary failures
    if (e is SocketException ||
        e is HttpException ||
        e is TranslationServiceUnavailableException) {
      return true;
    }

    // Retry on specific HTTP status codes
    if (e is TranslationApiException) {
      return e.statusCode >= 500 || e.statusCode == 429;
    }

    return true; // Retry on unknown errors
  }

  int? _parseRetryAfter(Map<String, String> headers) {
    final retryAfterHeader = headers['retry-after'] ?? headers['Retry-After'];
    if (retryAfterHeader != null) {
      return int.tryParse(retryAfterHeader);
    }
    return null;
  }
}

// Legacy function for backward compatibility
/// @deprecated Use [TranslationService.translateText] instead.
@Deprecated('Use TranslationService.translateText instead')
Future<String> translateText(String text, String targetLang) async {
  final config = await TranslatorConfig.fromFile();
  final service = TranslationService(config);
  try {
    return await service.translateText(text, targetLang);
  } finally {
    service.dispose();
  }
}
