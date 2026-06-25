// Copyright (c) 2024, Saurav Khanal. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

/// Main example demonstrating basic usage of arb_translator_gen_z.
///
/// This example shows:
/// - Basic translation of ARB files
/// - Configuration options
/// - Error handling
library;

import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  print('🌍 ARB Translator Gen Z - Basic Example');
  print('======================================\n');

  try {
    // Create translator instance with default configuration
    const config = TranslatorConfig();
    final translator = LocalizationTranslator(config);

    // Create sample ARB file if it doesn't exist
    final sampleArbFile = File('app_en.arb');
    if (!await sampleArbFile.exists()) {
      await sampleArbFile.writeAsString('''
{
  "@@locale": "en",
  "appTitle": "Hello World",
  "@appTitle": {
    "description": "The title of the application"
  },
  "welcomeMessage": "Welcome to our app!",
  "@welcomeMessage": {
    "description": "Welcome message shown to users"
  },
  "buttonText": "Get Started",
  "@buttonText": {
    "description": "Text for the main action button"
  }
}
''');
      print('✅ Created sample ARB file: ${sampleArbFile.path}');
    }

    // Translate to multiple languages
    final targetLanguages = ['es', 'fr', 'de', 'ja'];
    print('🔄 Translating to: ${targetLanguages.join(', ')}');

    for (final lang in targetLanguages) {
      print('\n📝 Translating to $lang...');

      final outputPath = await translator.generateForLanguage(
        sampleArbFile.path,
        lang,
      );

      print('✅ Translation complete: $outputPath');
    }

    print('\n🎉 All translations completed successfully!');
    print('📁 Check the generated ARB files.');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
