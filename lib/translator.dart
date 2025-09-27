import 'dart:convert';
import 'dart:io';

import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/exceptions/translation_exceptions.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

/// Enhanced translation service with retry logic, rate limiting, and comprehensive error handling.
///
/// This class provides robust translation capabilities using multiple translation APIs
/// with intelligent fallback mechanisms and rate limiting to prevent API abuse.
class TranslationService {
  /// Creates a [TranslationService] with the given [config].
  TranslationService(this._config) : _httpClient = http.Client();

  final TranslatorConfig _config;
  final http.Client _httpClient;
  final TranslatorLogger _logger = TranslatorLogger();

  DateTime _lastRequestTime = DateTime(1970);

  /// Translates the given [text] into the specified [targetLang].
  ///
  /// Uses intelligent retry logic and rate limiting to ensure reliable translation.
  /// Supports multiple translation APIs with automatic fallback.
  ///
  /// Example:
  /// ```dart
  /// final service = TranslationService(config);
  /// final translated = await service.translateText('Hello', 'es');
  /// print(translated); // Hola
  /// ```
  ///
  /// [text]: The string to translate. Must not be empty or null.
  /// [targetLang]: The target language code (e.g., 'es' for Spanish).
  /// [sourceLang]: Optional source language code (defaults to auto-detect).
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
  }) async {
    // Validate input
    _validateTranslationInput(text, targetLang);

    // Apply rate limiting
    await _applyRateLimit();

    // Use retry logic for robust translation
    const retryOptions = RetryOptions(maxAttempts: 3);

    try {
      return await retryOptions.retry(
        () => _performTranslation(text, targetLang, sourceLang),
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

  /// Disposes of the HTTP client resources.
  void dispose() {
    _httpClient.close();
  }

  Future<String> _performTranslation(
    String text,
    String targetLang,
    String? sourceLang,
  ) async {
    final source = sourceLang ?? _config.sourceLanguage;

    _logger.debug('Translating: "$text" ($source -> $targetLang)');

    // Try custom API endpoint first if configured
    if (_config.customApiEndpoint != null) {
      try {
        return await _translateWithCustomApi(text, targetLang, source);
      } catch (e) {
        _logger
            .warning('Custom API failed, falling back to Google Translate: $e');
      }
    }

    // Use Google Translate API
    return _translateWithGoogleApi(text, targetLang, source);
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
