import 'dart:async';
import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator.dart'
    show generateArbForLanguage;
import 'package:arb_translator_gen_z/languages.dart'
    show supportedLangCodes, validateLangCode;
import 'package:args/args.dart';

/// Command-line interface for the ARB Translator package.
///
/// This CLI allows you to translate a source ARB file into one or more
/// target languages.
///
/// Usage:
/// ```bash
/// dart run bin/main.dart -s lib/l10n/app_en.arb -l fr es ne
/// dart run bin/main.dart -s lib/l10n/app_en.arb -l all
/// ```
///
/// Options:
/// - `-s, --source` : Path to the source ARB file.
/// - `-l, --lang`   : Target language codes (space-separated or "all").
/// - `-h, --help`   : Display this help message.
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('source', abbr: 's', help: 'Source ARB file')
    ..addOption('lang',
        abbr: 'l', help: 'Target language codes (space separated or "all")')
    ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

  final argResults = parser.parse(arguments);

  // Display usage if help requested or required arguments are missing
  if (argResults['help'] ||
      !argResults.wasParsed('source') ||
      !argResults.wasParsed('lang')) {
    print(parser.usage);
    exit(0);
  }

  final sourceFile = argResults['source'] as String;
  final rawLangs = argResults['lang'] as String;

  // Determine target languages
  final targetLangs = rawLangs.toLowerCase() == 'all'
      ? supportedLangCodes.toList()
      : rawLangs.split(RegExp(r'\s+'));

  print('Languages to translate: $targetLangs');

  // Fire off all translations concurrently
  await Future.wait(targetLangs.map((lang) async {
    try {
      final validatedLang = validateLangCode(lang);
      print('🔹 Translating to $validatedLang...');
      await generateArbForLanguage(sourceFile, validatedLang);
      print('✅ Completed $validatedLang\n');
    } catch (e) {
      print('❌ Skipping "$lang": $e');
    }
  }));

  print('✅ All requested translations completed!');
}
