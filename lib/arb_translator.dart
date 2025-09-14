import 'arb_helper.dart';
import 'translator.dart';

// Future<void> generateArbForLanguage(
//   String sourcePath,
//   String targetLang,
// ) async {
//   final sourceContent = await readArbFile(sourcePath);
//   final targetContent = <String, dynamic>{'@@locale': targetLang};

//   for (var key in sourceContent.keys) {
//     if (key.startsWith('@') || key == '@@locale') {
//       targetContent[key] = sourceContent[key];
//       continue;
//     }
//     final translated = await translateText(sourceContent[key], targetLang);
//     targetContent[key] = translated;
//     print('Translated $key: $translated');
//   }

//   final targetPath = sourcePath.replaceAll(
//     RegExp(r'_en.arb$'),
//     '_$targetLang.arb',
//   );
//   await writeArbFile(targetPath, targetContent);
//   print('Generated $targetPath successfully!');
// }
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
        targetContent[key] = targetLang; // <-- set target locale
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
