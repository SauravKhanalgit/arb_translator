import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import '../lib/arb_translator.dart';
import 'package:arb_translator/languages.dart';

// void main(List<String> arguments) async {
//   final parser = ArgParser()
//     ..addOption('source', abbr: 's', help: 'Source ARB file')
//     ..addOption('lang', abbr: 'l', help: 'Target language code (e.g., fr)')
//     ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

//   final argResults = parser.parse(arguments);

//   if (argResults['help'] ||
//       !argResults.wasParsed('source') ||
//       !argResults.wasParsed('lang')) {
//     print(parser.usage);
//     exit(0);
//   }

//   final sourceFile = argResults['source'] as String;
//   final rawLang = argResults['lang'] as String;
//   final targetLang = validateLangCode(rawLang); // ✅ validate before using

//   await generateArbForLanguage(sourceFile, targetLang);
// }

// void main(List<String> arguments) async {
//   final parser = ArgParser()
//     ..addOption('source', abbr: 's', help: 'Source ARB file')
//     ..addOption('lang',
//         abbr: 'l', help: 'Target language codes (space separated)')
//     ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

//   final argResults = parser.parse(arguments);

//   if (argResults['help'] ||
//       !argResults.wasParsed('source') ||
//       !argResults.wasParsed('lang')) {
//     print(parser.usage);
//     exit(0);
//   }

//   final sourceFile = argResults['source'] as String;
//   final rawLangs = argResults['lang'] as String;

//   // Split space-separated language codes
//   final targetLangs = rawLangs.split(RegExp(r'\s+'));

//   for (var lang in targetLangs) {
//     try {
//       final validatedLang = validateLangCode(lang); // validate each code
//       print('🔹 Translating to $validatedLang...');
//       await generateArbForLanguage(sourceFile, validatedLang);
//     } catch (e) {
//       print('❌ Error for language "$lang": $e');
//     }
//   }
// }

// void main(List<String> arguments) async {
//   final parser = ArgParser()
//     ..addOption('source', abbr: 's', help: 'Source ARB file')
//     ..addOption('lang',
//         abbr: 'l', help: 'Target language codes (space separated or "all")')
//     ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

//   final argResults = parser.parse(arguments);

//   if (argResults['help'] ||
//       !argResults.wasParsed('source') ||
//       !argResults.wasParsed('lang')) {
//     print(parser.usage);
//     exit(0);
//   }

//   final sourceFile = argResults['source'] as String;
//   final rawLangs = argResults['lang'] as String;

//   // Determine target languages
//   final targetLangs = rawLangs.toLowerCase() == 'all'
//       ? supportedLangCodes
//       : rawLangs.split(RegExp(r'\s+'));

//   print('Languages to translate: $targetLangs');

//   // Translate concurrently but limit concurrency to avoid overwhelming Google
//   final concurrency = 5; // number of languages to translate simultaneously
//   final sem = StreamController<void>(sync: true);

//   await Future.wait(targetLangs.map((lang) async {
//     await sem.stream.first; // simple semaphore for concurrency
//     try {
//       final validatedLang = validateLangCode(lang);
//       print('🔹 Translating to $validatedLang...');
//       await generateArbForLanguage(sourceFile, validatedLang);
//       print('✅ Completed $validatedLang\n');
//     } catch (e) {
//       print('❌ Skipping "$lang": $e');
//     } finally {
//       sem.add(null);
//     }
//   }));

//   await sem.close();
//   print('✅ All requested translations completed!');
// }

// void main(List<String> arguments) async {
//   final parser = ArgParser()
//     ..addOption('source', abbr: 's', help: 'Source ARB file')
//     ..addOption('lang',
//         abbr: 'l', help: 'Target language codes (space separated or "all")')
//     ..addFlag('help', abbr: 'h', help: 'Display help', negatable: false);

//   final argResults = parser.parse(arguments);

//   if (argResults['help'] ||
//       !argResults.wasParsed('source') ||
//       !argResults.wasParsed('lang')) {
//     print(parser.usage);
//     exit(0);
//   }

//   final sourceFile = argResults['source'] as String;
//   final rawLangs = argResults['lang'] as String;

//   // Determine target languages
//   final targetLangs = rawLangs.toLowerCase() == 'all'
//       ? supportedLangCodes.toList()
//       : rawLangs.split(RegExp(r'\s+'));

//   print('Languages to translate: $targetLangs');

//   const concurrency = 5; // number of simultaneous translations

//   // Function to process in batches
//   Future<void> processBatch(List<String> batch) async {
//     await Future.wait(batch.map((lang) async {
//       try {
//         final validatedLang = validateLangCode(lang);
//         print('🔹 Translating to $validatedLang...');
//         await generateArbForLanguage(sourceFile, validatedLang);
//         print('✅ Completed $validatedLang\n');
//       } catch (e) {
//         print('❌ Skipping "$lang": $e');
//       }
//     }));
//   }

//   // Split targetLangs into batches of size `concurrency`
//   for (var i = 0; i < targetLangs.length; i += concurrency) {
//     final batch =
//         targetLangs.sublist(i, (i + concurrency).clamp(0, targetLangs.length));
//     await processBatch(batch);
//   }

//   print('✅ All requested translations completed!');
// }
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
