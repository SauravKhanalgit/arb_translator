# arb_translator_gen_z

A simple Dart CLI tool to automatically translate your `.arb` files into multiple languages.  
Perfect for Flutter internationalization (i18n) projects.

---

## ✨ Features
- Translate `.arb` files into one or multiple languages
- Supports **all major languages** (Google Translate coverage)
- Option to translate into **all supported languages** in one go
- Automatically updates `@@locale` in the translated `.arb` files
- No API key required (uses Google Translate free endpoint)  

---

## 🚀 Installation

### As a dependency
Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  arb_translator_gen_z: ^1.0.0

Then run:
dart pub get

As a CLI tool, activate it globally:
dart pub global activate arb_translator_gen_z

You can now run the CLI with:
arb_translator_gen_z


dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang "te ne ug" 
— for multiple languages

dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang ne
— for single language like Nepali

dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang all
— for all languages

