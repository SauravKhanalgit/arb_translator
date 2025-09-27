import 'package:arb_translator_gen_z/languages.dart';
import 'package:arb_translator_gen_z/src/exceptions/translation_exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('Language Support Tests', () {
    test('should have all popular languages', () {
      expect(popularLanguageCodes.length, greaterThan(10));

      // Check for common languages
      expect(popularLanguageCodes, contains('en'));
      expect(popularLanguageCodes, contains('es'));
      expect(popularLanguageCodes, contains('fr'));
      expect(popularLanguageCodes, contains('de'));
    });

    test('should validate language codes correctly', () {
      // Valid codes
      expect(validateLangCode('en'), equals('en'));
      expect(validateLangCode('EN'), equals('en'));
      expect(validateLangCode('Fr'), equals('fr'));

      // Invalid codes should throw
      expect(
        () => validateLangCode('invalid'),
        throwsA(isA<UnsupportedLanguageException>()),
      );
      expect(
        () => validateLangCode(''),
        throwsA(isA<UnsupportedLanguageException>()),
      );
    });

    test('should provide language information', () {
      final englishInfo = getLanguageInfo('en');
      expect(englishInfo, isNotNull);
      expect(englishInfo!.name, equals('English'));
      expect(englishInfo.nativeName, equals('English'));
      expect(englishInfo.code, equals('en'));
      expect(englishInfo.isRightToLeft, isFalse);

      final arabicInfo = getLanguageInfo('ar');
      expect(arabicInfo, isNotNull);
      expect(arabicInfo!.isRightToLeft, isTrue);
    });

    test('should suggest similar language codes', () {
      final suggestions = suggestLanguageCodes('fre');
      expect(suggestions, contains('fr'));

      final suggestions2 = suggestLanguageCodes('english');
      expect(suggestions2, contains('en'));
    });

    test('should format language lists correctly', () {
      final formatted = formatLanguageList(['en', 'fr']);
      expect(formatted.length, equals(2));
      expect(formatted[0], contains('English'));
      expect(formatted[1], contains('Français'));
    });

    test('should identify RTL languages', () {
      final rtlLangs = rightToLeftLanguages;
      expect(rtlLangs, contains('ar'));
      expect(rtlLangs, contains('he'));
      expect(rtlLangs, contains('fa'));
      expect(rtlLangs, isNot(contains('en')));
    });
  });
}
