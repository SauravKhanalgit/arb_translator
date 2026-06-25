import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

void main() async {
  print('Testing programmatic usage...');

  try {
    // Create default configuration
    const config = TranslatorConfig();

    // Initialize logger
    final logger = TranslatorLogger();
    logger.initialize(config.logLevel);

    // Create translator
    final translator = LocalizationTranslator(config);

    // Test translation to Spanish
    final outputPath = await translator.generateForLanguage(
      'lib/l10n/app_en.arb',
      'es',
    );

    print('✅ Translation completed: $outputPath');
    translator.dispose();
  } catch (e) {
    print('❌ Translation failed: $e');
  }
}
