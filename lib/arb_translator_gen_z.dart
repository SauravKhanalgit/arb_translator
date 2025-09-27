/// ARB Translator Gen Z - Modern, enterprise-grade ARB file translation tool.
///
/// A comprehensive Dart library for translating ARB (Application Resource Bundle)
/// files with advanced features designed for production Flutter applications.
///
/// ## Features (v2.1.0)
///
/// - **100+ Language Support**: Translate to over 100 languages with native names and regional variants
/// - **Translation Memory**: Intelligent caching system reducing API calls by up to 70%
/// - **Incremental Translation**: Smart diff detection for translating only changed strings
/// - **Interactive & Watch Modes**: Step-by-step translation and automatic file watching
/// - **Batch Processing**: Concurrent translation with enhanced performance (5 parallel requests)
/// - **Enterprise Reliability**: Retry logic, rate limiting, and comprehensive error handling
/// - **ARB Validation**: Pre and post-translation validation with specific error locations
/// - **Flexible Configuration**: YAML-based configuration with multiple named profiles
/// - **Rich CLI Interface**: Professional command-line tools with colored output and emoji indicators
/// - **Detailed Logging**: Structured logging with ETA and throughput metrics
///
/// ## Quick Start
///
/// ### Programmatic Usage
///
/// ```dart
/// import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
///
/// Future<void> main() async {
///   // Load configuration
///   final config = await TranslatorConfig.fromFile();
///
///   // Create translator
///   final translator = ArbTranslator(config);
///
///   try {
///     // Translate to French
///     await translator.generateArbForLanguage('lib/l10n/app_en.arb', 'fr');
///
///     // Batch translate to multiple languages
///     await translator.generateMultipleLanguages(
///       'lib/l10n/app_en.arb',
///       ['es', 'de', 'it', 'pt'],
///     );
///   } finally {
///     translator.dispose();
///   }
/// }
/// ```
///
/// ### CLI Usage
///
/// ```bash
/// # Install globally
/// dart pub global activate arb_translator_gen_z
///
/// # Translate to specific languages
/// arb_translator -s lib/l10n/app_en.arb -l "fr es de"
///
/// # Translate to all supported languages
/// arb_translator -s lib/l10n/app_en.arb -l all
///
/// # Validate ARB files
/// arb_translator -s lib/l10n/app_en.arb --validate-only
/// ```
///
/// ## Advanced Features
///
/// ### Custom Configuration
///
/// ```dart
/// final config = TranslatorConfig(
///   maxConcurrentTranslations: 10,
///   retryAttempts: 5,
///   logLevel: LogLevel.debug,
///   validateOutput: true,
/// );
/// ```
///
/// ### Error Handling
///
/// ```dart
/// try {
///   await translator.generateArbForLanguage('source.arb', 'fr');
/// } on ArbFileNotFoundException catch (e) {
///   print('Source file not found: ${e.filePath}');
/// } on TranslationApiException catch (e) {
///   print('API error ${e.statusCode}: ${e.details}');
/// }
/// ```
///
/// ### Language Utilities
///
/// ```dart
/// // Get language information
/// final info = getLanguageInfo('fr');
/// print('${info?.name}: ${info?.nativeName}'); // French: Français
///
/// // Validate and suggest languages
/// final validated = validateLangCode('FR'); // returns 'fr'
/// final suggestions = suggestLanguageCodes('fren'); // ['fr']
/// ```
///
/// ## Enterprise Integration
///
/// This library is designed for production use with features like:
///
/// - **CI/CD Integration**: Validation-only mode for build pipelines
/// - **Configuration Management**: Environment-specific settings
/// - **Monitoring**: Detailed logging and error reporting
/// - **Scalability**: Concurrent processing with rate limiting
/// - **Reliability**: Comprehensive error handling and retry logic
///
/// For complete documentation and examples, visit:
/// https://github.com/sauravkhanalgit/arb_translator
library arb_translator_gen_z; // Core translation functionality

export 'arb_helper.dart';
export 'arb_translator.dart';
export 'languages.dart';
// Configuration system
export 'src/config/translator_config.dart';
// Exception types
export 'src/exceptions/arb_exceptions.dart';
export 'src/exceptions/translation_exceptions.dart';
// Logging system
export 'src/logging/translator_logger.dart';
export 'translator.dart';
