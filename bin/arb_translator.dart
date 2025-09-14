import 'dart:async';
import 'dart:io';
import 'package:arb_translator_gen_z/languages.dart'
    show supportedLangCodes, validateLangCode;
import 'package:args/args.dart';
import '../lib/arb_translator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('source', abbr: 's', help: 'Source ARB file')
    ..addOption('lang',
        abbr: 'l', help: 'Target language codes (space separated or "all")')
    ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

  final argResults = parser.parse(arguments);

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

  // Fire off all translations at once
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
