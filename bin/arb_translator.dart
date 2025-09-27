import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:arb_translator_gen_z/arb_helper.dart';
import 'package:arb_translator_gen_z/arb_translator.dart';
import 'package:arb_translator_gen_z/languages.dart';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:arb_translator_gen_z/src/exceptions/translation_exceptions.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Enhanced command-line interface for the ARB Translator package.
///
/// This CLI provides comprehensive translation capabilities with advanced features
/// like configuration management, detailed logging, and intelligent error handling.
///
/// Usage:
/// ```bash
/// # Translate to specific languages
/// arb_translator -s lib/l10n/app_en.arb -l fr es de
///
/// # Translate to all supported languages
/// arb_translator -s lib/l10n/app_en.arb -l all
///
/// # Use custom configuration
/// arb_translator -s lib/l10n/app_en.arb -l fr --config config.yaml
///
/// # Generate default configuration file
/// arb_translator --init-config
/// ```
///
/// Options:
/// - `-s, --source`     : Path to the source ARB file.
/// - `-l, --languages`  : Target language codes (space-separated or "all").
/// - `-c, --config`     : Path to configuration file.
/// - `--init-config`    : Generate default configuration file.
/// - `--overwrite`      : Overwrite existing translation files.
/// - `--validate-only`  : Only validate source file without translating.
/// - `--list-languages` : Show all supported languages.
/// - `--popular`        : Show popular language codes.
/// - `--verbose`        : Enable debug logging.
/// - `--quiet`          : Suppress all output except errors.
/// - `-h, --help`       : Display this help message.
void main(List<String> arguments) async {
  final parser = _createArgParser();

  try {
    final argResults = parser.parse(arguments);
    await _handleCommand(argResults, parser);
  } catch (e) {
    stderr.writeln('Error parsing arguments: $e');
    stderr.writeln('Use --help for usage information.');
    exit(1);
  }
}

ArgParser _createArgParser() {
  return ArgParser()
    ..addOption(
      'source',
      abbr: 's',
      help: 'Path to the source ARB file (e.g., lib/l10n/app_en.arb)',
    )
    ..addOption(
      'languages',
      abbr: 'l',
      help:
          'Target language codes (space-separated) or "all" for all languages',
    )
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to configuration file (optional)',
    )
    ..addFlag(
      'init-config',
      help: 'Generate default configuration file and exit',
      negatable: false,
    )
    ..addFlag(
      'overwrite',
      help: 'Overwrite existing translation files (default: true)',
      defaultsTo: true,
    )
    ..addFlag(
      'validate-only',
      help: 'Only validate the source ARB file without translating',
      negatable: false,
    )
    ..addFlag(
      'list-languages',
      help: 'Show all supported language codes and exit',
      negatable: false,
    )
    ..addFlag(
      'popular',
      help: 'Show popular language codes and exit',
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging (debug level)',
      negatable: false,
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress all output except errors',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );
}

Future<void> _handleCommand(ArgResults argResults, ArgParser parser) async {
  // Handle help
  if (argResults['help'] as bool) {
    _showUsage(parser);
    return;
  }

  // Handle list languages
  if (argResults['list-languages'] as bool) {
    _showAllLanguages();
    return;
  }

  // Handle popular languages
  if (argResults['popular'] as bool) {
    _showPopularLanguages();
    return;
  }

  // Handle init config
  if (argResults['init-config'] as bool) {
    await _initializeConfig(argResults['config'] as String?);
    return;
  }

  // Validate required arguments for translation
  final sourceFile = argResults['source'] as String?;
  final rawLangs = argResults['languages'] as String?;
  final validateOnly = argResults['validate-only'] as bool;

  if (sourceFile == null) {
    stderr.writeln('Error: --source is required.');
    stderr.writeln('Use --help for usage information.');
    exit(1);
  }

  if (!validateOnly && rawLangs == null) {
    stderr.writeln('Error: --languages is required for translation.');
    stderr.writeln('Use --help for usage information.');
    exit(1);
  }

  // Load configuration
  final configPath = argResults['config'] as String?;
  final config = await _loadConfig(configPath, argResults);

  // Initialize logging
  final logger = TranslatorLogger();
  logger.initialize(config.logLevel);

  // Validate source file exists
  if (!await File(sourceFile).exists()) {
    logger.error('Source file not found: $sourceFile');
    exit(1);
  }

  // Handle validate-only mode
  if (validateOnly) {
    await _validateOnly(sourceFile, logger);
    return;
  }

  // Parse target languages (safe to use ! since we checked for null above)
  final targetLanguages = _parseTargetLanguages(rawLangs!, logger);

  if (targetLanguages.isEmpty) {
    logger.error('No valid target languages specified');
    exit(1);
  }

  // Perform translation
  await _performTranslation(
    sourceFile,
    targetLanguages,
    config,
    argResults['overwrite'] as bool,
    logger,
  );
}

void _showUsage(ArgParser parser) {
  print('ARB Translator - Advanced localization file translation tool');
  print('');
  print('Usage: arb_translator [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  # Translate to French and Spanish');
  print('  arb_translator -s lib/l10n/app_en.arb -l fr es');
  print('');
  print('  # Translate to all supported languages');
  print('  arb_translator -s lib/l10n/app_en.arb -l all');
  print('');
  print('  # Use custom configuration');
  print(
      '  arb_translator -s lib/l10n/app_en.arb -l fr --config my_config.yaml');
  print('');
  print('  # Validate ARB file only');
  print('  arb_translator -s lib/l10n/app_en.arb --validate-only');
  print('');
  print('  # Generate configuration file');
  print('  arb_translator --init-config');
}

void _showAllLanguages() {
  print('Supported Language Codes (${supportedLangCodes.length} total):');
  print('');

  final sortedLanguages = supportedLanguages.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  for (final lang in sortedLanguages) {
    final rtlIndicator = lang.isRightToLeft ? ' (RTL)' : '';
    print(
        '  ${lang.code.padRight(6)} ${lang.name} - ${lang.nativeName}$rtlIndicator');
  }

  print('');
  print('Use "all" to translate to all supported languages.');
}

void _showPopularLanguages() {
  print('Popular Language Codes:');
  print('');

  final formatted = formatLanguageList(popularLanguageCodes);
  for (final lang in formatted) {
    print('  $lang');
  }

  print('');
  print('These languages cover the majority of mobile app users worldwide.');
}

Future<void> _initializeConfig([String? configPath]) async {
  try {
    final config = const TranslatorConfig();
    await config.saveToFile(configPath);

    final actualPath = configPath ??
        '${Platform.environment['HOME'] ?? '.'}/.arb_translator/config.yaml';

    print('✅ Configuration file created: $actualPath');
    print('');
    print('You can now edit this file to customize translation settings.');
  } catch (e) {
    stderr.writeln('❌ Failed to create configuration file: $e');
    exit(1);
  }
}

Future<TranslatorConfig> _loadConfig(
    String? configPath, ArgResults argResults) async {
  try {
    var config = await TranslatorConfig.fromFile(configPath);

    // Override config with command-line arguments
    if (argResults['verbose'] as bool) {
      config = config.copyWith(logLevel: LogLevel.debug);
    } else if (argResults['quiet'] as bool) {
      config = config.copyWith(logLevel: LogLevel.error);
    }

    return config;
  } catch (e) {
    stderr.writeln(
        'Warning: Failed to load configuration file, using defaults: $e');
    return const TranslatorConfig();
  }
}

List<String> _parseTargetLanguages(String rawLangs, TranslatorLogger logger) {
  if (rawLangs.toLowerCase().trim() == 'all') {
    logger.info(
        'Translating to all ${supportedLangCodes.length} supported languages');
    return supportedLangCodes.toList()..sort();
  }

  final targetLangs = <String>[];
  final invalidLangs = <String>[];

  for (final lang in rawLangs
      .split(RegExp(r'[\s,]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)) {
    try {
      final validatedLang = validateLangCode(lang);
      targetLangs.add(validatedLang);
    } catch (e) {
      invalidLangs.add(lang);

      // Suggest similar languages
      final suggestions = suggestLanguageCodes(lang);
      if (suggestions.isNotEmpty) {
        logger.warning(
            'Invalid language code "$lang". Did you mean: ${suggestions.join(', ')}?');
      } else {
        logger.warning(
            'Invalid language code "$lang". Use --list-languages to see all supported codes.');
      }
    }
  }

  if (invalidLangs.isNotEmpty) {
    logger.error('${invalidLangs.length} invalid language codes found');
  }

  return targetLangs;
}

Future<void> _validateOnly(String sourceFile, TranslatorLogger logger) async {
  try {
    logger.info('Validating ARB file: $sourceFile');

    final content = await ArbHelper.readArbFile(sourceFile);
    final issues = ArbHelper.validateArbContent(content);

    if (issues.isEmpty) {
      logger.success('✅ ARB file validation passed');
      print('File contains ${content.length} entries');

      final translations = ArbHelper.getTranslations(content);
      final metadata = ArbHelper.getMetadata(content);

      print('  - ${translations.length} translatable entries');
      print('  - ${metadata.length} metadata entries');

      final locale = content['@@locale'] as String?;
      if (locale != null) {
        final info = getLanguageInfo(locale);
        print('  - Locale: $locale${info != null ? ' (${info.name})' : ''}');
      }
    } else {
      logger.error('❌ ARB file validation failed');
      for (final issue in issues) {
        print('  - $issue');
      }
      exit(1);
    }
  } catch (e) {
    logger.error('Failed to validate ARB file', e);
    exit(1);
  }
}

Future<void> _performTranslation(
  String sourceFile,
  List<String> targetLanguages,
  TranslatorConfig config,
  bool overwrite,
  TranslatorLogger logger,
) async {
  final translator = ArbTranslator(config);

  try {
    final startTime = DateTime.now();
    logger.info(
        'Starting translation of $sourceFile to ${targetLanguages.length} languages');

    // Show language list
    final languageNames = targetLanguages
        .map((code) => getLanguageInfo(code)?.name ?? code)
        .join(', ');
    logger.info('Target languages: $languageNames');

    final results = await translator.generateMultipleLanguages(
      sourceFile,
      targetLanguages,
      overwrite: overwrite,
    );

    final duration = DateTime.now().difference(startTime);
    final successful = results.values.where((path) => path.isNotEmpty).length;
    final failed = targetLanguages.length - successful;

    if (failed == 0) {
      logger.success(
          '🎉 All translations completed successfully in ${duration.inSeconds}s');
    } else {
      logger.warning(
          '⚠️  Translation completed with $failed failures in ${duration.inSeconds}s');
    }

    // Show results summary
    print('');
    print('Results:');
    for (final lang in targetLanguages) {
      final path = results[lang];
      if (path != null && path.isNotEmpty) {
        final info = getLanguageInfo(lang);
        final langName = info?.nativeName ?? lang;
        print('  ✅ $langName ($lang): $path');
      } else {
        print('  ❌ $lang: Failed');
      }
    }

    if (failed > 0) {
      exit(1);
    }
  } catch (e) {
    logger.error('Translation failed', e);

    if (e is ArbException || e is TranslationException) {
      // Don't show stack trace for known exceptions
      stderr.writeln('Error: $e');
    } else {
      // Show full error for unexpected issues
      stderr.writeln('Unexpected error: $e');
    }

    exit(1);
  } finally {
    translator.dispose();
  }
}
