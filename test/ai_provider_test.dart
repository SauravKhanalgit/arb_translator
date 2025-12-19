import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
import 'package:test/test.dart';

void main() {
  group('AI Provider Tests', () {
    late AIModelConfig config;

    setUp(() {
      // Use test configuration (no real API keys)
      config = const AIModelConfig(
        enableQualityScoring: true,
        enableAutoCorrection: false,
        qualityThreshold: 0.8,
      );
    });

    test('OpenAI provider availability check', () {
      final provider = OpenAIProvider(config, TranslatorLogger());
      expect(provider.provider, equals(TranslationProvider.openai));

      // Should not be available without API key
      expect(provider.isAvailable, isFalse);
      expect(provider.costPerCharacter, greaterThan(0));
      expect(provider.maxCharactersPerRequest, greaterThan(0));
    });

    test('DeepL provider availability check', () {
      final provider = DeepLProvider(config, TranslatorLogger());
      expect(provider.provider, equals(TranslationProvider.deepl));

      // Should not be available without API key
      expect(provider.isAvailable, isFalse);
      expect(provider.costPerCharacter, greaterThan(0));
      expect(provider.maxCharactersPerRequest, greaterThan(0));
    });

    test('Azure provider availability check', () {
      final provider = AzureProvider(config, TranslatorLogger());
      expect(provider.provider, equals(TranslationProvider.azure));

      // Should not be available without credentials
      expect(provider.isAvailable, isFalse);
      expect(provider.costPerCharacter, greaterThan(0));
      expect(provider.maxCharactersPerRequest, greaterThan(0));
    });

    test('AWS provider availability check', () {
      final provider = AWSProvider(config, TranslatorLogger());
      expect(provider.provider, equals(TranslationProvider.aws));

      // Should not be available without credentials
      expect(provider.isAvailable, isFalse);
      expect(provider.costPerCharacter, greaterThan(0));
      expect(provider.maxCharactersPerRequest, greaterThan(0));
    });

    test('AI provider manager initialization', () {
      final manager = AIProviderManager(
        const TranslatorConfig(aiModelConfig: AIModelConfig()),
        TranslatorLogger(),
      );

      expect(manager.providers, isNotEmpty);
      expect(manager.qualityScorer, isNotNull);

      // Should have all providers registered but none available
      expect(manager.providers.every((p) => !p.isAvailable), isTrue);
    });

    test('Quality scorer fallback behavior', () async {
      final scorer = QualityScorer([], TranslatorLogger());

      // Test fallback scoring without AI providers
      final score = await scorer.scoreTranslation(
        'Hello world',
        'Hola mundo',
        'en',
        'es',
      );

      expect(score, greaterThan(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('Translation result with quality score', () {
      final result = TranslationResult(
        text: 'Hola mundo',
        provider: TranslationProvider.google,
        qualityScore: 0.85,
      );

      expect(result.text, equals('Hola mundo'));
      expect(result.qualityScore, equals(0.85));
      expect(result.isHighQuality, isTrue);

      final improved = result.withQualityScore(0.95);
      expect(improved.qualityScore, equals(0.95));
    });
  });

  group('Translation Memory Tests', () {
    late TranslationMemory memory;
    late String tempFile;

    setUp(() async {
      tempFile = '/tmp/test_memory_${DateTime.now().millisecondsSinceEpoch}.json';
      memory = TranslationMemory(
        storagePath: tempFile,
        logger: TranslatorLogger(),
        maxEntries: 100,
      );
    });

    tearDown(() async {
      await memory.dispose();
      final file = File(tempFile);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Translation memory basic operations', () {
      final entry = TranslationEntry(
        sourceText: 'Hello world',
        translatedText: 'Hola mundo',
        sourceLang: 'en',
        targetLang: 'es',
        provider: 'google',
        qualityScore: 0.9,
        timestamp: DateTime.now(),
      );

      memory.addEntry(entry);

      final stats = memory.getStats();
      expect(stats['totalEntries'], equals(1));

      final suggestion = memory.suggestTranslation('Hello world', 'en', 'es');
      expect(suggestion, equals('Hola mundo'));
    });

    test('Translation memory fuzzy matching', () {
      memory.addEntry(TranslationEntry(
        sourceText: 'Click here to continue',
        translatedText: 'Haga clic aquí para continuar',
        sourceLang: 'en',
        targetLang: 'es',
        provider: 'google',
        qualityScore: 0.9,
        timestamp: DateTime.now(),
      ));

      // Should find fuzzy match for similar text
      final fuzzyMatches = memory.findFuzzyMatches(
        'Click here to proceed',
        'en',
        'es',
        minSimilarity: 0.5,
      );

      expect(fuzzyMatches, isNotEmpty);
      expect(fuzzyMatches.first.similarityScore, greaterThan(0.5));
    });

    test('Translation memory persistence', () async {
      memory.addEntry(TranslationEntry(
        sourceText: 'Test persistence',
        translatedText: 'Prueba de persistencia',
        sourceLang: 'en',
        targetLang: 'es',
        provider: 'test',
        qualityScore: 0.8,
        timestamp: DateTime.now(),
      ));

      await memory.saveToDisk();

      // Create new memory instance and load from disk
      final newMemory = TranslationMemory(
        storagePath: tempFile,
        logger: TranslatorLogger(),
      );

      final suggestion = newMemory.suggestTranslation('Test persistence', 'en', 'es');
      expect(suggestion, equals('Prueba de persistencia'));

      await newMemory.dispose();
    });

    test('Translation memory eviction', () {
      final maxEntries = 10;
      final smallMemory = TranslationMemory(
        storagePath: tempFile,
        logger: TranslatorLogger(),
        maxEntries: maxEntries,
      );

      // Add more entries than the limit
      for (var i = 0; i < maxEntries + 5; i++) {
        smallMemory.addEntry(TranslationEntry(
          sourceText: 'Test $i',
          translatedText: 'Prueba $i',
          sourceLang: 'en',
          targetLang: 'es',
          provider: 'test',
          qualityScore: 0.5 + (i * 0.01), // Different quality scores
          timestamp: DateTime.now(),
        ));
      }

      final stats = smallMemory.getStats();
      expect(stats['totalEntries'], lessThanOrEqualTo(maxEntries));
    });
  });

  group('Complex String Processing Tests', () {
    late ComplexStringProcessor processor;

    setUp(() {
      processor = ComplexStringProcessor(TranslatorLogger());
    });

    test('Complex string parsing - placeholders', () {
      final complex = ComplexString.parse('Hello {name}, you have {count} messages');

      expect(complex.placeholders, contains('{name}'));
      expect(complex.placeholders, contains('{count}'));
      expect(complex.isComplex, isTrue);
      expect(complex.translatableSegments.length, equals(4)); // "Hello ", ", you have ", " messages"
    });

    test('Complex string parsing - dates', () {
      final complex = ComplexString.parse('Today is 2024-01-15 and tomorrow is 01/16/2024');

      expect(complex.datePatterns, contains('2024-01-15'));
      expect(complex.datePatterns, contains('01/16/2024'));
      expect(complex.isComplex, isTrue);
    });

    test('Complex string parsing - numbers and currency', () {
      final complex = ComplexString.parse('Price: \$29.99 USD or €25.50 EUR');

      expect(complex.numberPatterns, contains('\$29.99 USD'));
      expect(complex.numberPatterns, contains('€25.50 EUR'));
      expect(complex.isComplex, isTrue);
    });

    test('Complex string reconstruction', () {
      final complex = ComplexString.parse('Hello {name}, welcome!');
      final translatedSegments = ['Hola', ', bienvenido!'];

      final result = complex.reconstruct(translatedSegments);
      expect(result, equals('Hola {name}, bienvenido!'));
    });

    test('String preprocessing and postprocessing', () {
      const original = 'Price: \$29.99 on 2024-01-15';
      final result = processor.preprocess(original);

      expect(result.needsSpecialHandling, isTrue);
      expect(result.processedText, isNot(equals(original)));

      // Postprocess should restore the original complex elements
      final translated = 'Precio: {{NUMBER_0}} en {{DATE_0}}';
      final finalResult = processor.postprocess(translated, result);

      expect(finalResult, equals('Precio: \$29.99 en 2024-01-15'));
    });

    test('Pluralization detection', () {
      final result = processor.processPluralization(
        'You have {count} items',
        'Tienes {count} elementos',
        'en',
        'es',
      );

      expect(result.isPluralized, isFalse); // No actual plural forms detected
      expect(result.pluralForms.isNotEmpty, isTrue);
    });
  });

  group('Format Handler Tests', () {
    test('Format handler registry', () {
      expect(FormatHandlerRegistry.supportedExtensions, isNotEmpty);
      expect(FormatHandlerRegistry.supportedExtensions, contains('arb'));
      expect(FormatHandlerRegistry.supportedExtensions, contains('json'));
    });

    test('ARB handler basic functionality', () {
      final handler = ArbHandler();

      expect(handler.extension, equals('arb'));
      expect(handler.name, equals('ARB (Application Resource Bundle)'));
    });

    test('JSON handler basic functionality', () {
      final handler = JsonHandler();

      expect(handler.extension, equals('json'));
      expect(handler.name, equals('JSON'));
    });

    test('CSV handler parsing', () {
      final handler = CsvHandler();

      // This would need actual CSV content to test fully
      expect(handler.extension, equals('csv'));
      expect(handler.name, equals('CSV'));
    });
  });
}
