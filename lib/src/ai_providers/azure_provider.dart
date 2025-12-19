import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arb_translator_gen_z/src/ai_providers/ai_provider.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Microsoft Azure Translator provider.
class AzureProvider extends AIProvider {
  /// Creates an [AzureProvider] with the given configuration.
  AzureProvider(super.config, super.logger);

  @override
  TranslationProvider get provider => TranslationProvider.azure;

  @override
  bool get isAvailable =>
      config.azureTranslatorKey != null &&
      config.azureTranslatorKey!.isNotEmpty &&
      config.azureTranslatorRegion != null &&
      config.azureTranslatorRegion!.isNotEmpty;

  @override
  double get costPerCharacter => 0.000018; // Azure Translator pricing

  @override
  int get maxCharactersPerRequest => 50000; // Azure's limit

  @override
  Future<TranslationResult> translate(
    String text,
    String sourceLang,
    String targetLang, {
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  }) async {
    validateAvailability();

    final startTime = DateTime.now();
    final url = 'https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=$sourceLang&to=$targetLang';

    // For Azure, we can include context in the text
    final enhancedText = description != null
        ? '$text\n\nContext: $description'
        : text;

    final body = <Map<String, dynamic>>[
      {'text': enhancedText}
    ];

    final response = await makeRequest(url, body);
    final data = json.decode(response.body);

    final translatedText = data[0]['translations'][0]['text'].toString();
    final detectedSourceLang = data[0]['detectedLanguage']?['language'];

    final processingTime = DateTime.now().difference(startTime).inMilliseconds;

    logger.debug('Azure translation completed: ${translatedText.length} chars, detected source: $detectedSourceLang');

    return TranslationResult(
      text: translatedText,
      provider: provider,
      processingTimeMs: processingTime,
    );
  }

  @override
  Future<double> scoreQuality(
    String sourceText,
    String translation,
    String sourceLang,
    String targetLang,
  ) async {
    // Azure doesn't provide direct quality scoring
    // Use confidence score if available, otherwise use heuristics
    validateAvailability();

    try {
      final url = 'https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=$sourceLang&to=$targetLang&includeAlignment=true';

      final body = <Map<String, dynamic>>[
        {'text': sourceText}
      ];

      final response = await makeRequest(url, body);
      final data = json.decode(response.body);

      final azureTranslation = data[0]['translations'][0]['text'].toString();
      final confidence = data[0]['translations'][0]['confidence'] as double?;

      if (confidence != null) {
        // Azure provides confidence scores
        return confidence.clamp(0.0, 1.0);
      } else {
        // Fallback to similarity-based scoring
        final similarity = _calculateSimilarity(translation, azureTranslation);
        return (0.7 + similarity * 0.3).clamp(0.0, 1.0);
      }
    } catch (e) {
      logger.warning('Failed to score quality with Azure: $e');
      return 0.7; // Default good score for Azure
    }
  }

  @override
  Future<String?> suggestCorrection(
    String sourceText,
    String poorTranslation,
    String sourceLang,
    String targetLang,
  ) async {
    try {
      final result = await translate(sourceText, sourceLang, targetLang);
      return result.text;
    } catch (e) {
      logger.warning('Failed to get Azure correction: $e');
      return null;
    }
  }

  @override
  Map<String, String> getHeaders() {
    return {
      'Ocp-Apim-Subscription-Key': config.azureTranslatorKey!,
      'Ocp-Apim-Subscription-Region': config.azureTranslatorRegion!,
      'Content-Type': 'application/json',
    };
  }

  /// Simple string similarity calculation.
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aWords = a.toLowerCase().split(RegExp(r'\s+'));
    final bWords = b.toLowerCase().split(RegExp(r'\s+'));

    final commonWords = aWords.where((word) => bWords.contains(word)).length;
    final totalWords = (aWords.length + bWords.length) / 2;

    return totalWords > 0 ? commonWords / totalWords : 0.0;
  }
}
