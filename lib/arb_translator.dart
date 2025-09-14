import 'arb_helper.dart';
import 'translator.dart';

/// Generates a translated ARB file for the specified [targetLang] based on the
/// [sourcePath] ARB file.
///
/// This function reads the source ARB file, translates all user-facing text
/// entries (ignoring metadata starting with '@' except for '@@locale'), and
/// writes a new ARB file for the target language.
///
/// Example:
/// ```dart
/// await generateArbForLanguage('lib/l10n/app_en.arb', 'fr');
/// // Generates lib/l10n/app_fr.arb
/// ```
///
/// [sourcePath]: The path to the source ARB file (e.g., 'lib/l10n/app_en.arb').
/// [targetLang]: The ISO-639 language code for the target translation (e.g., 'fr').
///
/// Throws [Exception] if reading or writing the ARB file fails or if
/// translation fails.
Future<void> generateArbForLanguage(
  String sourcePath,
  String targetLang,
) async {
  final sourceContent = await readArbFile(sourcePath);
  final targetContent = <String, dynamic>{};

  for (var key in sourceContent.keys) {
    if (key.startsWith('@')) {
      // Update @@locale, copy other metadata
      if (key == '@@locale') {
        targetContent[key] = targetLang; // set target locale
      } else {
        targetContent[key] = sourceContent[key];
      }
      continue;
    }

    final translated = await translateText(sourceContent[key], targetLang);
    targetContent[key] = translated;
    print('Translated $key: $translated');
  }

  final targetPath = sourcePath.replaceFirst(
    RegExp(r'_[a-z]{2}(\-[a-z]{2})?\.arb$'),
    '_$targetLang.arb',
  );
  await writeArbFile(targetPath, targetContent);
  print('Generated $targetPath successfully!');
}
