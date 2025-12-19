import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Represents a translation result with quality scoring.
class TranslationResult {
  /// Creates a [TranslationResult] with the given parameters.
  const TranslationResult({
    required this.text,
    required this.provider,
    this.qualityScore,
    this.confidence,
    this.tokensUsed,
    this.processingTimeMs,
  });

  /// The translated text.
  final String text;

  /// The provider used for translation.
  final TranslationProvider provider;

  /// Quality score from 0.0 to 1.0 (null if not scored).
  final double? qualityScore;

  /// Confidence score from 0.0 to 1.0.
  final double? confidence;

  /// Number of tokens used in the API call.
  final int? tokensUsed;

  /// Processing time in milliseconds.
  final int? processingTimeMs;

  /// Whether this translation meets quality standards.
  bool get isHighQuality => qualityScore == null || qualityScore! >= 0.7;

  /// Creates a copy with updated quality score.
  TranslationResult withQualityScore(double score) {
    return TranslationResult(
      text: text,
      provider: provider,
      qualityScore: score,
      confidence: confidence,
      tokensUsed: tokensUsed,
      processingTimeMs: processingTimeMs,
    );
  }
}

/// Base class for AI-powered translation providers.
abstract class AIProvider {
  /// Creates an [AIProvider] with the given configuration.
  AIProvider(this.config, this.logger);

  /// Configuration for this provider.
  final AIModelConfig config;

  /// Logger for this provider.
  final TranslatorLogger logger;

  /// The translation provider type.
  TranslationProvider get provider;

  /// Whether this provider is available (has required API keys).
  bool get isAvailable;

  /// Cost estimate per character (USD).
  double get costPerCharacter;

  /// Maximum characters per request.
  int get maxCharactersPerRequest;

  /// Translates text from source language to target language.
  Future<TranslationResult> translate(
    String text,
    String sourceLang,
    String targetLang, {
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  });

  /// Scores the quality of a translation (0.0 to 1.0).
  Future<double> scoreQuality(
    String sourceText,
    String translation,
    String sourceLang,
    String targetLang,
  );

  /// Gets a suggested correction for low-quality translation.
  Future<String?> suggestCorrection(
    String sourceText,
    String poorTranslation,
    String sourceLang,
    String targetLang,
  );

  /// Creates HTTP headers for API requests.
  Map<String, String> getHeaders();

  /// Makes an HTTP request with proper error handling.
  Future<http.Response> makeRequest(
    String url,
    dynamic body, {
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = getHeaders();
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    final startTime = DateTime.now();
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ).timeout(Duration(milliseconds: 30000));

      final processingTime = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        logger.debug(
          'API request successful: ${provider.name} (${processingTime}ms)',
        );
        return response;
      } else {
        logger.warning(
          'API request failed: ${provider.name} (${response.statusCode}) - ${response.body}',
        );
        throw AIProviderException(
          provider: provider,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      logger.error('API request error for ${provider.name}', e);
      rethrow;
    }
  }

  /// Validates that required API keys are available.
  void validateAvailability() {
    if (!isAvailable) {
      throw AIProviderException(
        provider: provider,
        message: 'Required API keys not configured for ${provider.name}',
      );
    }
  }
}

/// Exception thrown when AI provider operations fail.
class AIProviderException implements Exception {
  /// Creates an [AIProviderException] with the given parameters.
  const AIProviderException({
    required this.provider,
    this.statusCode,
    required this.message,
  });

  /// The provider that caused the exception.
  final TranslationProvider provider;

  /// HTTP status code if applicable.
  final int? statusCode;

  /// Error message.
  final String message;

  @override
  String toString() =>
      'AIProviderException: ${provider.name} - $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Quality scorer for evaluating translation quality.
class QualityScorer {
  /// Creates a [QualityScorer] with the given providers.
  QualityScorer(this.providers, this.logger);

  /// Available AI providers for quality scoring.
  final List<AIProvider> providers;

  /// Logger for quality scoring operations.
  final TranslatorLogger logger;

  /// Scores the quality of a translation using available AI providers.
  Future<double> scoreTranslation(
    String sourceText,
    String translation,
    String sourceLang,
    String targetLang,
  ) async {
    final availableProviders = providers.where((p) => p.isAvailable);

    if (availableProviders.isEmpty) {
      logger.debug('No AI providers available for quality scoring, using fallback');
      return _fallbackQualityScore(sourceText, translation);
    }

    // Try each provider and average the scores
    final scores = <double>[];
    for (final provider in availableProviders) {
      try {
        final score = await provider.scoreQuality(
          sourceText,
          translation,
          sourceLang,
          targetLang,
        );
        scores.add(score);
        logger.debug('${provider.provider.name} quality score: $score');
      } catch (e) {
        logger.warning('Failed to get quality score from ${provider.provider.name}: $e');
      }
    }

    if (scores.isEmpty) {
      return _fallbackQualityScore(sourceText, translation);
    }

    // Return average score
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;
    logger.debug('Average quality score: $averageScore');
    return averageScore;
  }

  /// Fallback quality scoring when no AI providers are available.
  double _fallbackQualityScore(String sourceText, String translation) {
    // Simple heuristic-based scoring
    if (translation.isEmpty || translation.trim().isEmpty) {
      return 0.0;
    }

    // Check for obvious issues
    final issues = <double>[];

    // Length ratio check (translations shouldn't be too different in length)
    final sourceLength = sourceText.length;
    final targetLength = translation.length;
    final ratio = targetLength / sourceLength;

    if (ratio < 0.3 || ratio > 3.0) {
      issues.add(0.3); // Significant length difference
    }

    // Check for placeholder preservation (simple check)
    final sourcePlaceholders = RegExp(r'%\w+|\{\w+\}|\$\w+').allMatches(sourceText);
    final targetPlaceholders = RegExp(r'%\w+|\{\w+\}|\$\w+').allMatches(translation);

    if (sourcePlaceholders.length != targetPlaceholders.length) {
      issues.add(0.4); // Placeholder mismatch
    }

    // Check for repeated characters (potential API issues)
    if (RegExp(r'(.)\1{4,}').hasMatch(translation)) {
      issues.add(0.2); // Excessive character repetition
    }

    if (issues.isEmpty) {
      return 0.8; // Decent fallback score
    }

    // Return score based on issues found
    final penalty = issues.reduce((a, b) => a + b) / issues.length;
    return (1.0 - penalty).clamp(0.0, 1.0);
  }
}
