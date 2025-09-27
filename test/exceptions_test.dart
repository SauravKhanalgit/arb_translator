import 'package:test/test.dart';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:arb_translator_gen_z/src/exceptions/translation_exceptions.dart';

void main() {
  group('Exception Tests', () {
    group('ARB Exceptions', () {
      test('ArbFileNotFoundException should contain file path', () {
        const exception = ArbFileNotFoundException('/path/to/file.arb');

        expect(exception.filePath, equals('/path/to/file.arb'));
        expect(exception.message, contains('/path/to/file.arb'));
        expect(exception.toString(), contains('ArbFileNotFoundException'));
      });

      test('ArbFileFormatException should contain details', () {
        const exception =
            ArbFileFormatException('/path/file.arb', 'Invalid JSON');

        expect(exception.filePath, equals('/path/file.arb'));
        expect(exception.details, equals('Invalid JSON'));
        expect(exception.toString(), contains('Invalid format'));
      });

      test('ArbFileWriteException should contain reason', () {
        const exception =
            ArbFileWriteException('/path/file.arb', 'Permission denied');

        expect(exception.filePath, equals('/path/file.arb'));
        expect(exception.reason, equals('Permission denied'));
        expect(exception.toString(), contains('Failed to write'));
      });

      test('ArbValidationException should contain issues', () {
        const issues = ['Missing @@locale', 'Empty value'];
        const exception = ArbValidationException('/path/file.arb', issues);

        expect(exception.filePath, equals('/path/file.arb'));
        expect(exception.issues, equals(issues));
        expect(exception.toString(), contains('Missing @@locale'));
      });
    });

    group('Translation Exceptions', () {
      test('UnsupportedLanguageException should contain language code', () {
        const exception = UnsupportedLanguageException('xyz');

        expect(exception.languageCode, equals('xyz'));
        expect(exception.toString(), contains('xyz'));
      });

      test('TranslationApiException should contain status code', () {
        const exception = TranslationApiException(404, 'Not found');

        expect(exception.statusCode, equals(404));
        expect(exception.details, equals('Not found'));
        expect(exception.toString(), contains('404'));
      });

      test('TranslationRateLimitException should handle retry after', () {
        const exceptionWithRetry = TranslationRateLimitException(30);
        const exceptionWithoutRetry = TranslationRateLimitException();

        expect(exceptionWithRetry.retryAfter, equals(30));
        expect(exceptionWithRetry.toString(), contains('30s'));

        expect(exceptionWithoutRetry.retryAfter, isNull);
        expect(
            exceptionWithoutRetry.toString(), isNot(contains('retry after')));
      });

      test('InvalidTranslationTextException should contain text and reason',
          () {
        const exception =
            InvalidTranslationTextException('', 'Text cannot be empty');

        expect(exception.text, equals(''));
        expect(exception.reason, equals('Text cannot be empty'));
        expect(exception.toString(), contains('Text cannot be empty'));
      });

      test('TranslationServiceUnavailableException should handle retry after',
          () {
        const exceptionWithRetry = TranslationServiceUnavailableException(60);
        const exceptionWithoutRetry = TranslationServiceUnavailableException();

        expect(exceptionWithRetry.retryAfter, equals(60));
        expect(exceptionWithRetry.toString(), contains('60s'));

        expect(exceptionWithoutRetry.retryAfter, isNull);
      });
    });
  });
}
