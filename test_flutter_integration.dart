import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

void main() async {
  print('Testing Flutter project integration...');

  try {
    // Test if package imports correctly
    const config = TranslatorConfig();
    print('✅ TranslatorConfig created successfully');

    // Test logger initialization
    final logger = TranslatorLogger();
    logger.initialize(config.logLevel);
    print('✅ TranslatorLogger initialized successfully');

    // Test translator creation
    final translator = ArbTranslator(config);
    print('✅ ArbTranslator created successfully');

    // Test language utilities
    final info = getLanguageInfo('fr');
    print('✅ Language info for French: ${info?.name} - ${info?.nativeName}');

    // Test popular languages
    print('✅ Popular languages: ${popularLanguageCodes.take(5).join(', ')}');

    translator.dispose();
    print(
      '🎉 All tests passed! Package is working correctly in Flutter project.',
    );
  } catch (e) {
    print('❌ Test failed: $e');
  }
}
