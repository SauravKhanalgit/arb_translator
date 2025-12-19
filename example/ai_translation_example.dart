/// AI-Powered Translation Examples for ARB Translator Gen Z
///
/// This example demonstrates advanced AI translation features including
/// multiple providers, quality scoring, and intelligent provider selection.
library;

import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  // Example 1: Basic AI translation with quality scoring
  await basicAITranslationExample();

  // Example 2: Multi-provider comparison
  await multiProviderComparisonExample();

  // Example 3: Quality scoring and auto-correction
  await qualityScoringExample();

  // Example 4: Cost optimization and provider selection
  await costOptimizationExample();

  // Example 5: Advanced configuration and customization
  await advancedConfigurationExample();
}

/// Example 1: Basic AI translation with quality scoring
Future<void> basicAITranslationExample() async {
  print('=== Basic AI Translation Example ===');

  // Configure with OpenAI for high-quality translations
  final config = TranslatorConfig(
    aiModelConfig: AIModelConfig(
      openaiApiKey: Platform.environment['OPENAI_API_KEY'], // Set your API key
      preferredProvider: TranslationProvider.openai,
      enableQualityScoring: true,
      enableAutoCorrection: true,
      qualityThreshold: 0.8,
    ),
  );

  final logger = TranslatorLogger()..initialize(config.logLevel);
  final translator = LocalizationTranslator(config);

  try {
    // Translate with AI-powered quality scoring
    final result = await translator.generateArbForLanguage(
      'lib/l10n/app_en.arb',
      'fr',
    );

    print('✅ Translation completed: $result');
    print('AI provider automatically selected and quality scored');
  } catch (e) {
    print('❌ Translation failed: $e');
  } finally {
    translator.dispose();
  }
}

/// Example 2: Multi-provider comparison
Future<void> multiProviderComparisonExample() async {
  print(r'\n=== Multi-Provider Comparison Example ===');

  // Configure multiple providers
  final config = TranslatorConfig(
    aiModelConfig: AIModelConfig(
      openaiApiKey: Platform.environment['OPENAI_API_KEY'],
      deeplApiKey: Platform.environment['DEEPL_API_KEY'],
      azureTranslatorKey: Platform.environment['AZURE_TRANSLATOR_KEY'],
      azureTranslatorRegion: Platform.environment['AZURE_TRANSLATOR_REGION'],
      enableQualityScoring: true,
    ),
  );

  final logger = TranslatorLogger()..initialize(config.logLevel);
  final service = TranslationService(config);

  try {
    const testText = 'Welcome to our amazing application!';
    const sourceLang = 'en';
    const targetLang = 'es';

    print('Translating: "$testText"');
    print('Source: $sourceLang → Target: $targetLang');
    print('');

    // Get cost estimates
    final costEstimates = service.getCostEstimates(testText);
    print('💰 Cost Estimates:');
    for (final entry in costEstimates.entries) {
      final cost = (entry.value * 100000).round() / 100; // Cost per 1000 chars
      print('  ${entry.key.displayName}: \$${cost} per 1000 chars');
    }
    print('');

    // Test each provider
    final providers = [
      TranslationProvider.openai,
      TranslationProvider.deepl,
      TranslationProvider.azure,
    ];

    for (final provider in providers) {
      try {
        print('🔄 Testing ${provider.displayName}...');

        // Create result using specific provider
        final result = await TranslationService(TranslatorConfig(
          aiModelConfig: config.aiModelConfig.copyWith(preferredProvider: provider),
        )).translateText(testText, targetLang, sourceLang: sourceLang);

        print('  ✅ "$result"');
        print('     Quality Score: N/A (use batch translation for quality scores)');
        print('     Processing Time: N/A (use batch translation for timing)');
        print('');
      } catch (e) {
        print('  ❌ ${provider.displayName} failed: $e');
        print('');
      }
    }
  } finally {
    service.dispose();
  }
}

/// Example 3: Quality scoring and auto-correction
Future<void> qualityScoringExample() async {
  print(r'\n=== Quality Scoring & Auto-Correction Example ===');

  final config = TranslatorConfig(
    aiModelConfig: AIModelConfig(
      openaiApiKey: Platform.environment['OPENAI_API_KEY'],
      preferredProvider: TranslationProvider.openai,
      enableQualityScoring: true,
      enableAutoCorrection: true,
      qualityThreshold: 0.85,
    ),
  );

  final logger = TranslatorLogger()..initialize(config.logLevel);
  final service = TranslationService(config);

  try {
    // Test with different quality translations
    final testCases = [
      {
        'source': 'Hello, how are you today?',
        'good': 'Hola, ¿cómo estás hoy?', // Good translation
        'poor': 'Hello, how you today?', // Poor translation
      },
      {
        'source': 'Click here to continue',
        'good': 'Haga clic aquí para continuar',
        'poor': 'Click to continue', // Poor translation
      },
    ];

    for (final testCase in testCases) {
      final sourceText = testCase['source']!;
      final goodTranslation = testCase['good']!;
      final poorTranslation = testCase['poor']!;

      print('📝 Source: "$sourceText"');
      print('🎯 Good translation: "$goodTranslation"');
      print('❌ Poor translation: "$poorTranslation"');
      print('');

      // Score the good translation
      final goodScore = await service.translateText(goodTranslation, 'es', sourceLang: 'en');
      print('  ✅ Good translation score: ${goodScore.qualityScore?.toStringAsFixed(2)}');

      // Score the poor translation
      final poorScore = await service.translateText(poorTranslation, 'es', sourceLang: 'en');
      print('  ❌ Poor translation score: ${poorScore.qualityScore?.toStringAsFixed(2)}');

      // Test auto-correction on poor translation
      if ((poorScore.qualityScore ?? 0) < config.aiModelConfig.qualityThreshold) {
        print('  🔧 Auto-correction triggered due to low quality score');

        // The service would automatically apply correction
        final correctedResult = await service.translateText(
          sourceText,
          'es',
          sourceLang: 'en',
        );

        print('  ✨ Corrected: "${correctedResult.text}"');
      }

      print('');
    }
  } finally {
    service.dispose();
  }
}

/// Example 4: Cost optimization and provider selection
Future<void> costOptimizationExample() async {
  print(r'\n=== Cost Optimization Example ===');

  final config = TranslatorConfig(
    aiModelConfig: AIModelConfig(
      openaiApiKey: Platform.environment['OPENAI_API_KEY'],
      deeplApiKey: Platform.environment['DEEPL_API_KEY'],
      azureTranslatorKey: Platform.environment['AZURE_TRANSLATOR_KEY'],
      azureTranslatorRegion: Platform.environment['AZURE_TRANSLATOR_REGION'],
      preferredProvider: TranslationProvider.google, // Start with free option
    ),
  );

  final logger = TranslatorLogger()..initialize(config.logLevel);
  final service = TranslationService(config);

  try {
    // Simulate a large translation project
    final sampleTexts = [
      'Welcome to our application',
      'Please enter your email address',
      'Your password must be at least 8 characters',
      'Click here to reset your password',
      'Thank you for using our service',
      'An error occurred while processing your request',
      'Your account has been successfully created',
      'Please verify your email address to continue',
      'This field is required',
      'Invalid email format',
    ];

    final totalText = sampleTexts.join(' ');
    print('📊 Analyzing cost for ${sampleTexts.length} strings (${totalText.length} characters)');
    print('');

    final costEstimates = service.getCostEstimates(totalText);

    print('💰 Cost Comparison (for ${totalText.length} characters):');
    for (final entry in costEstimates.entries) {
      final cost = entry.value;
      final costPerThousand = (cost * 1000 / totalText.length * 100).round() / 100;
      print('  ${entry.key.displayName}: \$${cost.toStringAsFixed(4)} (~\$${costPerThousand}/1000 chars)');
    }
    print('');

    // Find cheapest available provider
    final availableCosts = costEstimates.entries.where((e) => e.value > 0).toList();
    if (availableCosts.isNotEmpty) {
      availableCosts.sort((a, b) => a.value.compareTo(b.value));
      final cheapest = availableCosts.first;

      print('💡 Recommendation: Use ${cheapest.key.displayName} (cheapest available)');
      print('   Estimated cost: \$${cheapest.value.toStringAsFixed(4)}');
    }

    // Show quality vs cost trade-off
    print('');
    print('⚖️  Quality vs Cost Analysis:');
    print('  🟢 OpenAI GPT: Highest quality, higher cost');
    print('  🟡 DeepL: High quality, medium cost');
    print('  🟠 Azure: Good quality, lower cost');
    print('  🔵 Google: Decent quality, free/low cost');

  } finally {
    service.dispose();
  }
}

/// Example 5: Advanced configuration and customization
Future<void> advancedConfigurationExample() async {
  print(r'\n=== Advanced Configuration Example ===');

  // Create a production-ready configuration
  final prodConfig = TranslatorConfig(
    maxConcurrentTranslations: 10,
    retryAttempts: 5,
    rateLimitDelayMs: 200,
    aiModelConfig: AIModelConfig(
      openaiApiKey: Platform.environment['OPENAI_API_KEY'],
      deeplApiKey: Platform.environment['DEEPL_API_KEY'],
      azureTranslatorKey: Platform.environment['AZURE_TRANSLATOR_KEY'],
      azureTranslatorRegion: Platform.environment['AZURE_TRANSLATOR_REGION'],
      preferredProvider: TranslationProvider.openai,
      qualityThreshold: 0.9,
      enableQualityScoring: true,
      enableAutoCorrection: true,
      maxTokensPerRequest: 2000,
    ),
    logLevel: LogLevel.info,
    preserveMetadata: true,
    prettyPrintJson: true,
    validateOutput: true,
  );

  final logger = TranslatorLogger()..initialize(prodConfig.logLevel);
  final service = TranslationService(prodConfig);

  try {
    // Test provider health
    print('🔍 Testing provider health...');
    final testResults = await service.testAIProviders();

    final workingProviders = testResults.entries.where((e) => e.value).length;
    print('✅ $workingProviders/${testResults.length} providers are working');

    // Show provider statistics
    print('');
    print('📊 Provider Statistics:');
    final stats = service.getAIProviderStats();
    for (final provider in stats['providers']) {
      final status = provider['available'] ? '✅' : '❌';
      print('  $status ${provider['name']}');
    }

    // Demonstrate batch processing with quality scoring
    print('');
    print('🔄 Batch Translation with Quality Scoring:');

    final batchTexts = {
      'greeting': 'Hello, welcome to our app!',
      'error': 'Something went wrong. Please try again.',
      'success': 'Your action was completed successfully.',
    };

    // Note: This would normally use the ArbTranslator for full ARB processing
    // Here we're just demonstrating the service capabilities
    for (final entry in batchTexts.entries) {
      try {
        final result = await service.translateText(
          entry.value,
          'fr',
          sourceLang: 'en',
        );

        print('  "${entry.key}": "${result.text}"');
        if (result.qualityScore != null) {
          final score = result.qualityScore!.toStringAsFixed(2);
          final quality = result.qualityScore! >= prodConfig.aiModelConfig.qualityThreshold
              ? '✅'
              : '⚠️';
          print('    Quality: $quality $score');
        }
      } catch (e) {
        print('  "${entry.key}": ❌ Failed - $e');
      }
    }

  } finally {
    service.dispose();
  }
}
