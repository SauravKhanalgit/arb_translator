import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:arb_translator_gen_z/src/ai_providers/ai_provider.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Amazon Web Services Translate provider.
class AWSProvider extends AIProvider {
  /// Creates an [AWSProvider] with the given configuration.
  AWSProvider(super.config, super.logger);

  @override
  TranslationProvider get provider => TranslationProvider.aws;

  @override
  bool get isAvailable =>
      config.awsTranslateAccessKey != null &&
      config.awsTranslateAccessKey!.isNotEmpty &&
      config.awsTranslateSecretKey != null &&
      config.awsTranslateSecretKey!.isNotEmpty;

  @override
  double get costPerCharacter => 0.000015; // AWS Translate pricing

  @override
  int get maxCharactersPerRequest => 10000; // AWS limit

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

    // Convert language codes to AWS format
    final awsSourceLang = _convertToAwsCode(sourceLang);
    final awsTargetLang = _convertToAwsCode(targetLang);

    final url = 'https://translate.${config.awsTranslateRegion}.amazonaws.com/';

    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final date = dateStamp.substring(0, 8);

    // For AWS, we can include context in the text
    final enhancedText = description != null
        ? '$text\n\nContext: $description'
        : text;

    final payload = {
      'Text': enhancedText,
      'SourceLanguageCode': awsSourceLang,
      'TargetLanguageCode': awsTargetLang,
    };

    final canonicalRequest = _buildCanonicalRequest('POST', '/', payload, dateStamp, date);
    final stringToSign = _buildStringToSign(canonicalRequest, date, config.awsTranslateRegion);
    final signature = _calculateSignature(stringToSign, date, config.awsTranslateRegion);

    final authorization = 'AWS4-HMAC-SHA256 Credential=${config.awsTranslateAccessKey}/$date/${config.awsTranslateRegion}/translate/aws4_request, SignedHeaders=host;x-amz-date, Signature=$signature';

    final headers = {
      'Authorization': authorization,
      'X-Amz-Date': dateStamp,
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target': 'AWSShineFrontendService_20170701.TranslateText',
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(payload),
    ).timeout(Duration(milliseconds: 30000));

    if (response.statusCode != 200) {
      throw AIProviderException(
        provider: provider,
        statusCode: response.statusCode,
        message: response.body,
      );
    }

    final data = json.decode(response.body);
    final translatedText = data['TranslatedText'].toString();

    final processingTime = DateTime.now().difference(startTime).inMilliseconds;

    logger.debug('AWS translation completed: ${translatedText.length} chars');

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
    // AWS doesn't provide quality scoring directly
    // Use confidence from the API if available, otherwise heuristics
    try {
      final result = await translate(sourceText, sourceLang, targetLang);
      final awsTranslation = result.text;

      // Simple quality scoring based on similarity
      final similarity = _calculateSimilarity(translation, awsTranslation);
      return (0.75 + similarity * 0.25).clamp(0.0, 1.0);
    } catch (e) {
      logger.warning('Failed to score quality with AWS: $e');
      return 0.75; // Default score for AWS
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
      logger.warning('Failed to get AWS correction: $e');
      return null;
    }
  }

  @override
  Map<String, String> getHeaders() {
    // Headers are built in the translate method for AWS
    return {};
  }

  /// Converts standard language codes to AWS format.
  String _convertToAwsCode(String code) {
    // AWS uses different codes for some languages
    const awsCodes = {
      'zh-cn': 'zh-CN',
      'zh-tw': 'zh-TW',
      'pt-pt': 'pt-PT',
      'pt-br': 'pt-BR',
      'en-us': 'en-US',
      'en-gb': 'en-GB',
    };

    final lowerCode = code.toLowerCase();
    return awsCodes[lowerCode] ?? code;
  }

  String _formatDate(DateTime date) {
    return date.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';
  }

  String _buildCanonicalRequest(String method, String canonicalUri, Map<String, dynamic> payload, String dateStamp, String date) {
    final payloadHash = sha256.convert(utf8.encode(json.encode(payload))).toString();
    final canonicalHeaders = 'host:translate.${config.awsTranslateRegion}.amazonaws.com\nx-amz-date:$dateStamp\n';
    final signedHeaders = 'host;x-amz-date';

    return '$method\n$canonicalUri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
  }

  String _buildStringToSign(String canonicalRequest, String date, String region) {
    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$date/$region/translate/aws4_request';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    return '$algorithm\n$date\n$credentialScope\n$canonicalRequestHash';
  }

  String _calculateSignature(String stringToSign, String date, String region) {
    final kDate = Hmac(sha256, utf8.encode('AWS4${config.awsTranslateSecretKey}')).convert(utf8.encode(date));
    final kRegion = Hmac(sha256, kDate.bytes).convert(utf8.encode(region));
    final kService = Hmac(sha256, kRegion.bytes).convert(utf8.encode('translate'));
    final kSigning = Hmac(sha256, kService.bytes).convert(utf8.encode('aws4_request'));

    return Hmac(sha256, kSigning.bytes).convert(utf8.encode(stringToSign)).toString();
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
