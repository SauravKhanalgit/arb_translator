import 'dart:io';

import 'package:arb_translator_gen_z/arb_helper.dart';
import 'package:arb_translator_gen_z/src/exceptions/arb_exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('ARB Helper Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('arb_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should read valid ARB file', () async {
      final arbFile = File('${tempDir.path}/test.arb');
      await arbFile.writeAsString('''
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "The title of the application"
  }
}
''');

      final content = await ArbHelper.readArbFile(arbFile.path);

      expect(content['@@locale'], equals('en'));
      expect(content['appTitle'], equals('My App'));
      expect(content['@appTitle'], isA<Map<String, dynamic>>());
    });

    test('should throw ArbFileNotFoundException for missing file', () async {
      final nonexistentFile = '${tempDir.path}/nonexistent.arb';

      expect(
        () => ArbHelper.readArbFile(nonexistentFile),
        throwsA(isA<ArbFileNotFoundException>()),
      );
    });

    test('should throw ArbFileFormatException for invalid JSON', () async {
      final arbFile = File('${tempDir.path}/invalid.arb');
      await arbFile.writeAsString('{ invalid json }');

      expect(
        () => ArbHelper.readArbFile(arbFile.path),
        throwsA(isA<ArbFileFormatException>()),
      );
    });

    test('should validate ARB content correctly', () {
      // Valid ARB content
      final validContent = {
        '@@locale': 'en',
        'appTitle': 'My App',
        '@appTitle': {'description': 'App title'},
      };

      final validIssues = ArbHelper.validateArbContent(validContent);
      expect(validIssues, isEmpty);

      // Invalid ARB content (missing @@locale)
      final invalidContent = {
        'appTitle': 'My App',
      };

      final invalidIssues = ArbHelper.validateArbContent(invalidContent);
      expect(invalidIssues, isNotEmpty);
      expect(invalidIssues.first, contains('@@locale'));
    });

    test('should write ARB file correctly', () async {
      final arbFile = File('${tempDir.path}/output.arb');
      final content = {
        '@@locale': 'fr',
        'appTitle': 'Mon App',
      };

      await ArbHelper.writeArbFile(arbFile.path, content);

      expect(await arbFile.exists(), isTrue);

      final writtenContent = await ArbHelper.readArbFile(arbFile.path);
      expect(writtenContent['@@locale'], equals('fr'));
      expect(writtenContent['appTitle'], equals('Mon App'));
    });

    test('should separate metadata and translations', () {
      final content = {
        '@@locale': 'en',
        '@@version': '1.0',
        'appTitle': 'My App',
        'welcomeMessage': 'Hello!',
        '@appTitle': {'description': 'App title'},
      };

      final metadata = ArbHelper.getMetadata(content);
      expect(metadata.length, equals(3));
      expect(
        metadata.keys,
        containsAll(['@@locale', '@@version', '@appTitle']),
      );

      final translations = ArbHelper.getTranslations(content);
      expect(translations.length, equals(2));
      expect(translations.keys, containsAll(['appTitle', 'welcomeMessage']));
    });

    test('should handle empty ARB file validation', () {
      final emptyContent = <String, dynamic>{};
      final issues = ArbHelper.validateArbContent(emptyContent);

      expect(issues, isNotEmpty);
      expect(issues.first, equals('ARB file is empty'));
    });

    test('should detect null and empty values', () {
      final contentWithIssues = {
        '@@locale': 'en',
        'validKey': 'Valid value',
        'nullKey': null,
        'emptyKey': '',
        '': 'Empty key value',
      };

      final issues = ArbHelper.validateArbContent(contentWithIssues);
      expect(issues.length, greaterThan(2));

      final issuesText = issues.join(' ');
      expect(issuesText, contains('Null value'));
      expect(issuesText, contains('Empty'));
    });
  });
}
