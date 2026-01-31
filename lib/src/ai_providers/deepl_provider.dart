import 'dart:convert';
import 'package:arb_translator_gen_z/src/ai_providers/ai_provider.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';

/// DeepL provider for high-quality neural machine translation.
class DeepLProvider extends AIProvider {
  /// Creates a [DeepLProvider] with the given configuration.
  DeepLProvider(super.config, super.logger);

  @override
  TranslationProvider get provider => TranslationProvider.deepl;

  @override
  bool get isAvailable =>
      config.deeplApiKey != null && config.deeplApiKey!.isNotEmpty;

  @override
  double get costPerCharacter => 0.00002; // DeepL Pro pricing

  @override
  int get maxCharactersPerRequest => 50000; // DeepL's limit

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

    // DeepL uses different language codes
    final deeplSourceLang = _convertToDeeplCode(sourceLang);
    final deeplTargetLang = _convertToDeeplCode(targetLang);

    final url = 'https://api.deepl.com/v2/translate';

    // For DeepL, we can include context in the text if provided
    final enhancedText =
        description != null ? '$text\n\nContext: $description' : text;

    final body = {
      'text': [enhancedText],
      'source_lang': deeplSourceLang,
      'target_lang': deeplTargetLang,
      'preserve_formatting': '1',
    };

    final response = await makeRequest(url, body);
    final data = json.decode(response.body);

    final translatedText = data['translations'][0]['text'].toString();
    final detectedSourceLang =
        data['translations'][0]['detected_source_language'];

    final processingTime = DateTime.now().difference(startTime).inMilliseconds;

    logger.debug(
        'DeepL translation completed: ${translatedText.length} chars, detected source: $detectedSourceLang');

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
    // DeepL doesn't provide quality scoring directly
    // Use a simple heuristic based on translation confidence
    // In a real implementation, you might use a separate quality assessment model

    validateAvailability();

    final deeplSourceLang = _convertToDeeplCode(sourceLang);
    final deeplTargetLang = _convertToDeeplCode(targetLang);

    final url = 'https://api.deepl.com/v2/translate';
    final body = {
      'text': [sourceText],
      'source_lang': deeplSourceLang,
      'target_lang': deeplTargetLang,
      'preserve_formatting': '1',
    };

    try {
      final response = await makeRequest(url, body);
      final data = json.decode(response.body);
      final deeplTranslation = data['translations'][0]['text'].toString();

      // Simple quality scoring based on similarity and length
      final similarity = _calculateSimilarity(translation, deeplTranslation);
      final lengthRatio = translation.length / deeplTranslation.length;

      // DeepL is generally high quality, so start with high score
      double score = 0.9;

      // Adjust based on similarity to DeepL's own translation
      score -= (1.0 - similarity) * 0.3;

      // Adjust based on length differences
      if (lengthRatio < 0.7 || lengthRatio > 1.4) {
        score -= 0.1;
      }

      return score.clamp(0.0, 1.0);
    } catch (e) {
      logger.warning('Failed to score quality with DeepL: $e');
      return 0.8; // High default score for DeepL
    }
  }

  @override
  Future<String?> suggestCorrection(
    String sourceText,
    String poorTranslation,
    String sourceLang,
    String targetLang,
  ) async {
    // For DeepL, we can just return the DeepL translation as a suggestion
    try {
      final result = await translate(sourceText, sourceLang, targetLang);
      return result.text;
    } catch (e) {
      logger.warning('Failed to get DeepL correction: $e');
      return null;
    }
  }

  @override
  Map<String, String> getHeaders() {
    return {
      'Authorization': 'DeepL-Auth-Key ${config.deeplApiKey}',
      'Content-Type': 'application/json',
    };
  }

  /// Converts standard language codes to DeepL format.
  String _convertToDeeplCode(String code) {
    // DeepL uses different codes for some languages
    const deeplCodes = {
      'en': 'EN',
      'de': 'DE',
      'fr': 'FR',
      'es': 'ES',
      'pt': 'PT',
      'it': 'IT',
      'nl': 'NL',
      'pl': 'PL',
      'ru': 'RU',
      'ja': 'JA',
      'zh': 'ZH',
      'ar': 'AR',
      'bg': 'BG',
      'cs': 'CS',
      'da': 'DA',
      'el': 'EL',
      'et': 'ET',
      'fi': 'FI',
      'hu': 'HU',
      'lt': 'LT',
      'lv': 'LV',
      'ro': 'RO',
      'sk': 'SK',
      'sl': 'SL',
      'sv': 'SV',
      'tr': 'TR',
      'uk': 'UK',
      // Regional variants
      'en-us': 'EN-US',
      'en-gb': 'EN-GB',
      'pt-pt': 'PT-PT',
      'pt-br': 'PT-BR',
      'zh-cn': 'ZH',
      'zh-tw': 'ZH',
    };

    final lowerCode = code.toLowerCase();
    return deeplCodes[lowerCode] ?? code.toUpperCase();
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
