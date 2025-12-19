import 'dart:math';
import 'package:arb_translator_gen_z/src/ai_providers/ai_provider.dart';
import 'package:arb_translator_gen_z/src/ai_providers/openai_provider.dart';
import 'package:arb_translator_gen_z/src/ai_providers/deepl_provider.dart';
import 'package:arb_translator_gen_z/src/ai_providers/azure_provider.dart';
import 'package:arb_translator_gen_z/src/ai_providers/aws_provider.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Manages multiple AI translation providers and provides intelligent selection.
class AIProviderManager {
  /// Creates an [AIProviderManager] with the given configuration.
  AIProviderManager(this.config, this.logger) {
    _initializeProviders();
    _qualityScorer = QualityScorer(_providers, logger);
  }

  /// Configuration for AI providers.
  final TranslatorConfig config;

  /// Logger for the manager.
  final TranslatorLogger logger;

  /// List of available AI providers.
  late final List<AIProvider> _providers;

  /// Quality scorer for evaluating translations.
  late final QualityScorer _qualityScorer;

  /// Gets all available providers.
  List<AIProvider> get providers => List.unmodifiable(_providers);

  /// Gets the quality scorer.
  QualityScorer get qualityScorer => _qualityScorer;

  /// Initializes all AI providers based on configuration.
  void _initializeProviders() {
    _providers = [];

    // OpenAI Provider
    if (config.aiModelConfig.openaiApiKey != null) {
      _providers.add(OpenAIProvider(config.aiModelConfig, logger));
      logger.info('OpenAI provider initialized');
    }

    // DeepL Provider
    if (config.aiModelConfig.deeplApiKey != null) {
      _providers.add(DeepLProvider(config.aiModelConfig, logger));
      logger.info('DeepL provider initialized');
    }

    // Azure Provider
    if (config.aiModelConfig.azureTranslatorKey != null &&
        config.aiModelConfig.azureTranslatorRegion != null) {
      _providers.add(AzureProvider(config.aiModelConfig, logger));
      logger.info('Azure Translator provider initialized');
    }

    // AWS Provider
    if (config.aiModelConfig.awsTranslateAccessKey != null &&
        config.aiModelConfig.awsTranslateSecretKey != null) {
      _providers.add(AWSProvider(config.aiModelConfig, logger));
      logger.info('AWS Translate provider initialized');
    }

    if (_providers.isEmpty) {
      logger.warning('No AI providers configured. Quality scoring and advanced features will be limited.');
    } else {
      logger.info('Initialized ${_providers.length} AI providers');
    }
  }

  /// Translates text using the best available provider.
  Future<TranslationResult> translate(
    String text,
    String sourceLang,
    String targetLang, {
    TranslationProvider? preferredProvider,
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  }) async {
    final provider = _selectProvider(preferredProvider ?? config.aiModelConfig.preferredProvider);

    if (provider == null) {
      throw AIProviderException(
        provider: config.aiModelConfig.preferredProvider,
        message: 'No suitable AI provider available for translation',
      );
    }

    logger.debug('Using ${provider.provider.name} for translation');

    final result = await provider.translate(text, sourceLang, targetLang);

    // Add quality scoring if enabled
    if (config.aiModelConfig.enableQualityScoring) {
      try {
        final qualityScore = await _qualityScorer.scoreTranslation(
          text,
          result.text,
          sourceLang,
          targetLang,
        );

        logger.debug('Translation quality score: $qualityScore');

        // Auto-correct if quality is below threshold and auto-correction is enabled
        if (qualityScore < config.aiModelConfig.qualityThreshold &&
            config.aiModelConfig.enableAutoCorrection) {
          logger.info('Low quality score ($qualityScore), attempting auto-correction');

          final correction = await provider.suggestCorrection(
            text,
            result.text,
            sourceLang,
            targetLang,
          );

          if (correction != null && correction != result.text) {
            final correctedResult = TranslationResult(
              text: correction,
              provider: result.provider,
              qualityScore: qualityScore, // Keep original score for reference
              tokensUsed: result.tokensUsed,
              processingTimeMs: result.processingTimeMs,
            );

            logger.info('Auto-correction applied');
            return correctedResult;
          }
        }

        return result.withQualityScore(qualityScore);
      } catch (e) {
        logger.warning('Failed to score translation quality: $e');
        return result;
      }
    }

    return result;
  }

  /// Gets translation cost estimates for all available providers.
  Map<TranslationProvider, double> getCostEstimates(String text) {
    final estimates = <TranslationProvider, double>{};

    for (final provider in _providers) {
      final cost = text.length * provider.costPerCharacter;
      estimates[provider.provider] = cost;
    }

    return estimates;
  }

  /// Selects the best provider based on availability, cost, and preferences.
  AIProvider? _selectProvider(TranslationProvider preferred) {
    // First, try to find the preferred provider
    final preferredProvider = _providers.where((p) => p.provider == preferred).firstOrNull;
    if (preferredProvider != null) {
      return preferredProvider;
    }

    // If preferred provider is not available, select based on strategy
    final availableProviders = _providers.where((p) => p.isAvailable).toList();
    if (availableProviders.isEmpty) {
      return null;
    }

    // For now, use a simple strategy: prefer quality over cost
    // Order: OpenAI -> DeepL -> Azure -> AWS -> Google (fallback)
    const priorityOrder = [
      TranslationProvider.openai,
      TranslationProvider.deepl,
      TranslationProvider.azure,
      TranslationProvider.aws,
    ];

    for (final providerType in priorityOrder) {
      final provider = availableProviders.where((p) => p.provider == providerType).firstOrNull;
      if (provider != null) {
        return provider;
      }
    }

    // Fallback to any available provider
    return availableProviders.first;
  }

  /// Gets provider statistics and health information.
  Map<String, dynamic> getProviderStats() {
    final stats = <String, dynamic>{
      'total_providers': _providers.length,
      'available_providers': _providers.where((p) => p.isAvailable).length,
      'providers': <Map<String, dynamic>>[],
    };

    for (final provider in _providers) {
      stats['providers'].add({
        'name': provider.provider.displayName,
        'available': provider.isAvailable,
        'cost_per_char': provider.costPerCharacter,
        'max_chars': provider.maxCharactersPerRequest,
      });
    }

    return stats;
  }

  /// Tests all providers to ensure they're working correctly.
  Future<Map<TranslationProvider, bool>> testProviders() async {
    final results = <TranslationProvider, bool>{};
    const testText = 'Hello, world!';
    const testSource = 'en';
    const testTarget = 'es';

    for (final provider in _providers) {
      try {
        await provider.translate(testText, testSource, testTarget);
        results[provider.provider] = true;
        logger.debug('${provider.provider.name} test passed');
      } catch (e) {
        results[provider.provider] = false;
        logger.warning('${provider.provider.name} test failed: $e');
      }
    }

    return results;
  }
}

/// Extension methods for List.
extension ListExtension<T> on List<T> {
  /// Gets the first element or null if the list is empty.
  T? get firstOrNull => isEmpty ? null : first;

  /// Gets the last element or null if the list is empty.
  T? get lastOrNull => isEmpty ? null : last;
}
