import 'dart:convert';
import 'package:arb_translator_gen_z/src/ai_providers/ai_provider.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';

/// OpenAI GPT provider for high-quality translations.
class OpenAIProvider extends AIProvider {
  /// Creates an [OpenAIProvider] with the given configuration.
  OpenAIProvider(super.config, super.logger);

  @override
  TranslationProvider get provider => TranslationProvider.openai;

  @override
  bool get isAvailable =>
      config.openaiApiKey != null && config.openaiApiKey!.isNotEmpty;

  @override
  double get costPerCharacter =>
      0.00002; // Approximate cost per character for GPT-3.5

  @override
  int get maxCharactersPerRequest => 12000; // Conservative limit for GPT models

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
    const url = 'https://api.openai.com/v1/chat/completions';

    final prompt = _buildTranslationPrompt(text, sourceLang, targetLang,
        description: description,
        surroundingContext: surroundingContext,
        keyName: keyName);
    final body = {
      'model': 'gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a professional translator specializing in software localization. Use the provided context to make accurate, culturally appropriate translations. Only return the translation, no explanations.',
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'max_tokens': config.maxTokensPerRequest,
      'temperature': 0.3, // Lower temperature for more consistent translations
    };

    final response = await makeRequest(url, body);
    final data = json.decode(response.body);

    final translatedText =
        data['choices'][0]['message']['content'].toString().trim();
    final tokensUsed = data['usage']['total_tokens'] as int;

    final processingTime = DateTime.now().difference(startTime).inMilliseconds;

    logger.debug(
        'OpenAI translation completed: ${translatedText.length} chars, $tokensUsed tokens');

    return TranslationResult(
      text: translatedText,
      provider: provider,
      tokensUsed: tokensUsed,
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
    validateAvailability();

    const url = 'https://api.openai.com/v1/chat/completions';

    final prompt = '''
Evaluate the quality of this translation on a scale from 0.0 to 1.0, where:
- 1.0 = Perfect translation (accurate, natural, preserves meaning)
- 0.8 = Good translation (minor issues but understandable)
- 0.6 = Acceptable translation (some errors but conveys main meaning)
- 0.4 = Poor translation (significant errors, hard to understand)
- 0.2 = Very poor translation (major errors, misleading)
- 0.0 = Completely wrong or unusable

Source ($sourceLang): "$sourceText"
Translation ($targetLang): "$translation"

Consider:
- Accuracy: Does it preserve the original meaning?
- Naturalness: Does it sound natural in the target language?
- Completeness: Are all parts of the source translated?
- Grammar: Is the grammar correct?

Return only a number between 0.0 and 1.0, no explanation.
''';

    final body = {
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 10,
      'temperature': 0.1,
    };

    try {
      final response = await makeRequest(url, body);
      final data = json.decode(response.body);
      final scoreText =
          data['choices'][0]['message']['content'].toString().trim();

      // Parse the score
      final score = double.tryParse(scoreText) ?? 0.5;
      return score.clamp(0.0, 1.0);
    } catch (e) {
      logger.warning('Failed to score quality with OpenAI: $e');
      return 0.5; // Neutral score on failure
    }
  }

  @override
  Future<String?> suggestCorrection(
    String sourceText,
    String poorTranslation,
    String sourceLang,
    String targetLang,
  ) async {
    validateAvailability();

    const url = 'https://api.openai.com/v1/chat/completions';

    final prompt = '''
The following translation has quality issues. Please provide a corrected version:

Source ($sourceLang): "$sourceText"
Current Translation ($targetLang): "$poorTranslation"

Provide only the corrected translation, no explanations or additional text.
''';

    final body = {
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': config.maxTokensPerRequest,
      'temperature': 0.3,
    };

    try {
      final response = await makeRequest(url, body);
      final data = json.decode(response.body);
      final correctedText =
          data['choices'][0]['message']['content'].toString().trim();

      return correctedText.isNotEmpty ? correctedText : null;
    } catch (e) {
      logger.warning('Failed to get correction suggestion from OpenAI: $e');
      return null;
    }
  }

  @override
  Map<String, String> getHeaders() {
    return {
      'Authorization': 'Bearer ${config.openaiApiKey}',
      'Content-Type': 'application/json',
    };
  }

  String _buildTranslationPrompt(
    String text,
    String sourceLang,
    String targetLang, {
    String? description,
    Map<String, String>? surroundingContext,
    String? keyName,
  }) {
    final sourceLangName = _getLanguageName(sourceLang);
    final targetLangName = _getLanguageName(targetLang);

    final buffer = StringBuffer();

    buffer.writeln(
        'Translate the following text from $sourceLangName ($sourceLang) to $targetLangName ($targetLang):');
    buffer.writeln();
    buffer.writeln('Text: "$text"');

    // Add context information
    if (description != null && description.isNotEmpty) {
      buffer.writeln('Context/Description: $description');
    }

    if (keyName != null && keyName.isNotEmpty) {
      buffer.writeln('Key/Identifier: $keyName');
    }

    if (surroundingContext != null && surroundingContext.isNotEmpty) {
      buffer.writeln('Surrounding Context:');
      surroundingContext.forEach((key, value) {
        buffer.writeln('  $key: "$value"');
      });
    }

    buffer.writeln();
    buffer.writeln('Important guidelines:');
    buffer
        .writeln('- Preserve the exact meaning and tone of the original text');
    buffer.writeln(
        '- Consider the context and description for accurate translation');
    buffer.writeln(
        '- Keep technical terms and proper nouns as they are (unless they have standard translations)');
    buffer.writeln(
        '- Maintain any placeholders, variables, or special formatting (e.g., {name}, \${variable})');
    buffer.writeln(
        '- Ensure the translation is natural and fluent in $targetLangName');
    buffer.writeln('- Do not add extra explanations or comments');
    buffer.writeln();
    buffer.writeln('Translation:');

    return buffer.toString();
  }

  String _getLanguageName(String code) {
    // Simple language name mapping for common languages
    const names = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'da': 'Danish',
      'no': 'Norwegian',
      'fi': 'Finnish',
      'pl': 'Polish',
      'tr': 'Turkish',
      'cs': 'Czech',
      'hu': 'Hungarian',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'he': 'Hebrew',
      'el': 'Greek',
    };

    return names[code] ?? code.toUpperCase();
  }
}
