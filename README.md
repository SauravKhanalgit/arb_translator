# ARB Translator Gen Z 🌍

[![pub package](https://img.shields.io/pub/v/arb_translator_gen_z.svg)](https://pub.dev/packages/arb_translator_gen_z)
[![pub points](https://img.shields.io/pub/points/arb_translator_gen_z)](https://pub.dev/packages/arb_translator_gen_z/score)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/arb_translator_gen_z)](https://pub.dev/packages/arb_translator_gen_z)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Translate Flutter `.arb` files to 100+ languages in one command.**

Free via Google Translate — no API key needed. Or plug in OpenAI, DeepL, Azure, or AWS for higher quality. Works as a CLI tool or a Dart library.

```bash
# Install once
dart pub global activate arb_translator_gen_z

# Translate to French, Spanish, and German
arb_translator -s lib/l10n/app_en.arb -l fr es de
```

---

## Contents

- [Features](#-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [CLI Reference](#-cli-reference)
- [Configuration](#-configuration)
- [AI Providers](#-ai-providers)
- [Programmatic API](#-programmatic-api)
- [Supported Languages](#-supported-languages)
- [CI/CD Integration](#-cicd-integration)
- [Contributing](#-contributing)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Free translation** | Google Translate — no API key, no account needed |
| **AI providers** | OpenAI · DeepL · Azure Translator · AWS Translate |
| **100+ languages** | Full native-name support, RTL detection |
| **Parallel processing** | Up to 5× faster with concurrent batch requests |
| **Translation memory** | In-session caching cuts repeated API calls |
| **Watch mode** | Auto-translate whenever your source ARB changes |
| **Interactive mode** | Confirm each string before it's written |
| **Diff preview** | See what will change before applying |
| **Validate-only** | Check ARB format without translating (great for CI) |
| **Custom output dir** | Write translated files anywhere with `-o` |
| **Retry & rate limiting** | Exponential backoff and configurable delays |
| **Full programmatic API** | Use everything from Dart code |

---

## 🚀 Installation

### CLI (global)

```bash
dart pub global activate arb_translator_gen_z
```

Make sure `~/.pub-cache/bin` is in your `PATH`:

```bash
# zsh
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc && source ~/.zshrc

# bash
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc && source ~/.bashrc
```

Verify:

```bash
arb_translator --help
```

### Library (project dependency)

```yaml
# pubspec.yaml
dependencies:
  arb_translator_gen_z: ^3.3.0
```

```bash
dart pub get
```

---

## 🎮 Quick Start

### Translate to specific languages

```bash
arb_translator -s lib/l10n/app_en.arb -l fr es de
```

Repeat `-l` or space-separate — both work:

```bash
arb_translator -s lib/l10n/app_en.arb -l fr -l es -l de
```

### Translate to all 100+ languages

```bash
arb_translator -s lib/l10n/app_en.arb -l all
```

### Custom output directory

```bash
arb_translator -s lib/l10n/app_en.arb -l fr es -o build/l10n
```

### Use a specific AI provider

```bash
# Requires OPENAI_API_KEY in your environment
arb_translator -s lib/l10n/app_en.arb -l fr --ai-provider openai
```

### Preview changes before writing

```bash
arb_translator -s lib/l10n/app_en.arb -l fr --diff
```

### Auto-translate on file changes (watch mode)

```bash
arb_translator -s lib/l10n/app_en.arb -l fr es --watch
```

### Validate only (no translation)

```bash
arb_translator -s lib/l10n/app_en.arb --validate-only
```

---

## 📋 CLI Reference

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--source` | `-s` | Source ARB file path | — |
| `--languages` | `-l` | Target language codes (repeat or space-separate, or `all`) | — |
| `--output-dir` | `-o` | Directory for translated files (defaults to source dir) | — |
| `--ai-provider` | | AI provider: `google` `openai` `deepl` `azure` `aws` | `google` |
| `--config` | `-c` | Path to YAML config file | `~/.arb_translator/config.yaml` |
| `--overwrite` | | Overwrite existing translations | `true` |
| `--verbose` | `-v` | Debug-level logging | `false` |
| `--quiet` | `-q` | Suppress non-error output | `false` |

### Commands / flags

| Flag | Description |
|------|-------------|
| `--help` `-h` | Show help |
| `--init-config` | Create starter config file at `~/.arb_translator/config.yaml` |
| `--list-languages` | List all 100+ supported languages |
| `--popular` | Show the most-used language codes |
| `--validate-only` | Validate ARB file structure without translating |
| `--diff` | Preview changes without writing files |
| `--interactive` | Confirm each string before translating |
| `--watch` | Watch source file and re-translate on changes |
| `--stats` | Show translation statistics and cache info |
| `--test-ai-providers` | Health-check all configured AI providers |
| `--ai-stats` | Show AI provider details and availability |
| `--clean-cache` | Clear the translation memory cache |

### Examples

```bash
# 1. Translate to European languages
arb_translator -s lib/l10n/app_en.arb -l fr es de it pt nl

# 2. Translate to Asian languages
arb_translator -s lib/l10n/app_en.arb -l ja ko zh zh-TW

# 3. All languages, custom output dir
arb_translator -s lib/l10n/app_en.arb -l all -o build/l10n

# 4. OpenAI for highest quality
arb_translator -s lib/l10n/app_en.arb -l fr de --ai-provider openai

# 5. DeepL for European languages
arb_translator -s lib/l10n/app_en.arb -l fr de es --ai-provider deepl

# 6. CI: validate then translate quietly
arb_translator -s lib/l10n/app_en.arb --validate-only --quiet
arb_translator -s lib/l10n/app_en.arb -l fr es de --quiet

# 7. Interactive — confirm each string
arb_translator -s lib/l10n/app_en.arb -l fr --interactive

# 8. Watch during development
arb_translator -s lib/l10n/app_en.arb -l fr es --watch

# 9. Check translation stats and cache usage
arb_translator --stats -s lib/l10n/app_en.arb

# 10. Test all configured AI providers
arb_translator --test-ai-providers
```

---

## ⚙️ Configuration

Generate a starter config file:

```bash
arb_translator --init-config
```

This creates `~/.arb_translator/config.yaml`:

```yaml
# Maximum parallel translation requests (higher = faster, but more API load)
maxConcurrentTranslations: 5

# Retry behaviour
retryAttempts: 3
retryDelayMs: 1000
requestTimeoutMs: 30000

# Rate limiting between requests (ms)
rateLimitDelayMs: 100

# Source language ("auto" detects from @@locale)
sourceLanguage: "auto"

# Output formatting
prettyPrintJson: true
backupOriginal: false
validateOutput: true

# Logging: debug | info | warning | error
logLevel: "info"
```

You can also pass a config file explicitly:

```bash
arb_translator -s lib/l10n/app_en.arb -l fr -c ci_config.yaml
```

---

## 🤖 AI Providers

By default, the tool uses **Google Translate** (free, no key required). For higher quality or specialised languages, configure an AI provider.

### Provider comparison

| Provider | Quality | Cost | Setup |
|----------|---------|------|-------|
| Google Translate | ⭐⭐⭐ | Free | Nothing — works out of the box |
| OpenAI GPT-4 | ⭐⭐⭐⭐⭐ | $$$ | `OPENAI_API_KEY` |
| DeepL | ⭐⭐⭐⭐⭐ | $$ | `DEEPL_API_KEY` |
| Azure Translator | ⭐⭐⭐⭐ | $$ | `AZURE_TRANSLATOR_KEY` + region |
| AWS Translate | ⭐⭐⭐ | $$ | `AWS_TRANSLATE_ACCESS_KEY` + secret + region |

### Set up an AI provider

**Via environment variables (recommended):**

```bash
export OPENAI_API_KEY="sk-..."
arb_translator -s lib/l10n/app_en.arb -l fr --ai-provider openai
```

**Via config file:**

```yaml
# ~/.arb_translator/config.yaml
aiModel:
  preferredProvider: "openai"   # google | openai | deepl | azure | aws
  qualityThreshold: 0.8
  enableAutoCorrection: false
  maxTokensPerRequest: 4000

  openaiApiKey: "${OPENAI_API_KEY}"
  deeplApiKey: "${DEEPL_API_KEY}"
  azureTranslatorKey: "${AZURE_TRANSLATOR_KEY}"
  azureTranslatorRegion: "eastus"
  awsTranslateAccessKey: "${AWS_ACCESS_KEY_ID}"
  awsTranslateSecretKey: "${AWS_SECRET_ACCESS_KEY}"
  awsTranslateRegion: "us-east-1"
```

### Test provider health

```bash
arb_translator --test-ai-providers
```

---

## 🔧 Programmatic API

### Basic usage

```dart
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  const config = TranslatorConfig();
  final translator = LocalizationTranslator(config);

  try {
    // Single language
    final path = await translator.generateForLanguage(
      'lib/l10n/app_en.arb',
      'fr',
    );
    print('Written to: $path');

    // Multiple languages
    final results = await translator.generateMultipleLanguages(
      'lib/l10n/app_en.arb',
      ['es', 'de', 'it', 'pt', 'ja'],
    );
    for (final entry in results.entries) {
      print('${entry.key}: ${entry.value}');
    }
  } finally {
    translator.dispose();
  }
}
```

### Custom configuration

```dart
const config = TranslatorConfig(
  maxConcurrentTranslations: 10,  // parallelism
  retryAttempts: 5,
  logLevel: LogLevel.warning,     // quieter for CI
  rateLimitDelayMs: 200,
);
```

### AI provider configuration

```dart
import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

final config = TranslatorConfig(
  aiModelConfig: AIModelConfig(
    openaiApiKey: Platform.environment['OPENAI_API_KEY'],
    preferredProvider: TranslationProvider.openai,
    enableAutoCorrection: true,
  ),
);

final translator = LocalizationTranslator(config);
final path = await translator.generateForLanguage('lib/l10n/app_en.arb', 'fr');
translator.dispose();
```

### Custom output directory

```dart
final path = await translator.generateForLanguage(
  'lib/l10n/app_en.arb',
  'fr',
  outputDir: 'build/l10n',
);
```

### ARB file utilities

```dart
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

// Read and validate
final content = await ArbHelper.readArbFile('lib/l10n/app_en.arb');
final issues = ArbHelper.validateArbContent(content);
if (issues.isNotEmpty) {
  print('Validation issues: $issues');
}

// Extract translations vs metadata
final translations = ArbHelper.getTranslations(content);
final metadata    = ArbHelper.getMetadata(content);
```

### Language utilities

```dart
// Get language info
final info = getLanguageInfo('fr');
print('${info?.name}: ${info?.nativeName}'); // French: Français

// Validate a code (returns normalised code or null)
final code = validateLangCode('FR'); // returns 'fr'

// Typo suggestions
final suggestions = suggestLanguageCodes('fren'); // ['fr']

// List all codes
print(supportedLangCodes.length); // 100+
```

### Translation service (direct)

```dart
final service = TranslationService(config);

try {
  // Single string
  final translated = await service.translateText('Hello', 'es', sourceLang: 'en');
  print(translated); // Hola

  // Batch strings
  final batch = await service.translateBatch(
    {'greeting': 'Hello', 'farewell': 'Goodbye'},
    'es',
  );
  print(batch); // {greeting: Hola, farewell: Adiós}

  // Cost estimates across providers
  final costs = service.getCostEstimates('Hello, world!');

  // Provider health check
  final health = await service.testAIProviders();
} finally {
  await service.dispose();
}
```

### Error handling

```dart
try {
  await translator.generateForLanguage('app_en.arb', 'fr');
} on ArbFileNotFoundException catch (e) {
  print('File not found: ${e.filePath}');
} on ArbFileFormatException catch (e) {
  print('Bad ARB format in ${e.filePath}: ${e.details}');
} on UnsupportedLanguageException catch (e) {
  final hints = suggestLanguageCodes(e.languageCode);
  print('Unknown language "${e.languageCode}". Try: $hints');
} on TranslationApiException catch (e) {
  print('API error ${e.statusCode}: ${e.details}');
}
```

---

## 🌐 Supported Languages

100+ languages with native names. Quick reference:

```
af  Afrikaans      ar  العربية        bg  Български      bn  বাংলা
ca  Català         cs  Čeština        cy  Cymraeg        da  Dansk
de  Deutsch        el  Ελληνικά       en  English        es  Español
et  Eesti          fa  فارسی          fi  Suomi          fr  Français
gu  ગુજરાતી         he  עברית          hi  हिन्दी           hr  Hrvatski
hu  Magyar         hy  Հայերեն        id  Indonesia      is  Íslenska
it  Italiano       ja  日本語           ka  ქართული        kn  ಕನ್ನಡ
ko  한국어            lt  Lietuvių       lv  Latviešu       mk  Македонски
ml  മലയാളം          mr  मराठी           ms  Melayu         mt  Malti
nl  Nederlands     no  Norsk          pa  ਪੰਜਾਬੀ          pl  Polski
pt  Português      ro  Română         ru  Русский        sk  Slovenčina
sl  Slovenščina    sq  Shqip          sr  Српски         sv  Svenska
sw  Kiswahili      ta  தமிழ்          te  తెలుగు          th  ภาษาไทย
tl  Filipino       tr  Türkçe         uk  Українська     ur  اردو
vi  Tiếng Việt     zh  中文(简体)        zh-TW 中文(繁體)
```

```bash
# See all languages
arb_translator --list-languages

# Show popular codes only
arb_translator --popular
```

---

## 🏗️ CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/translate.yml
name: Translate ARB Files

on:
  push:
    paths:
      - 'lib/l10n/app_en.arb'

jobs:
  translate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1

      - name: Install ARB Translator
        run: dart pub global activate arb_translator_gen_z

      - name: Validate source file
        run: arb_translator -s lib/l10n/app_en.arb --validate-only

      - name: Translate
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          arb_translator \
            -s lib/l10n/app_en.arb \
            -l fr es de it pt ja ko zh \
            --ai-provider openai \
            --quiet

      - name: Commit translations
        run: |
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add lib/l10n/
          git diff --cached --quiet || git commit -m "chore: update translations"
          git push
```

### Dart code in CI

```dart
import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> main() async {
  const config = TranslatorConfig(logLevel: LogLevel.warning);
  final translator = LocalizationTranslator(config);

  try {
    // Validate first — exits non-zero if invalid
    final content = await ArbHelper.readArbFile('lib/l10n/app_en.arb');
    final issues  = ArbHelper.validateArbContent(content);
    if (issues.isNotEmpty) {
      stderr.writeln('Validation failed:\n${issues.join('\n')}');
      exit(1);
    }

    // Translate required languages
    final langs = Platform.environment['REQUIRED_LANGUAGES']?.split(',')
        ?? ['fr', 'es', 'de'];

    final results = await translator.generateMultipleLanguages(
      'lib/l10n/app_en.arb',
      langs,
    );

    final failed = results.entries.where((e) => e.value.isEmpty).toList();
    if (failed.isNotEmpty) {
      stderr.writeln('Failed: ${failed.map((e) => e.key).join(', ')}');
      exit(1);
    }

    print('All translations generated.');
  } finally {
    translator.dispose();
  }
}
```

---

## 📁 ARB File Format

A valid ARB file looks like this:

```json
{
  "@@locale": "en",

  "appTitle": "My App",
  "@appTitle": {
    "description": "The application title shown in the header"
  },

  "greeting": "Hello, {name}!",
  "@greeting": {
    "description": "Personalized greeting",
    "placeholders": {
      "name": { "type": "String" }
    }
  },

  "itemCount": "{count, plural, one{1 item} other{{count} items}}",
  "@itemCount": {
    "description": "Item count with pluralization",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

The translator preserves all `@` metadata and copies placeholders unchanged.

---

## 📈 Performance

With default settings (`maxConcurrentTranslations: 5`):

| Strings | 1 language | 10 languages | All languages (100+) |
|---------|-----------|-------------|----------------------|
| 10      | ~1s        | ~5s          | ~2 min               |
| 50      | ~3s        | ~20s         | ~8 min               |
| 200     | ~10s       | ~1 min       | ~30 min              |

Increase `maxConcurrentTranslations` for faster results (watch rate limits):

```bash
# In config.yaml
maxConcurrentTranslations: 10
```

Translation memory avoids re-translating identical strings across runs in the same session.

---

## 🛠️ Development

```bash
git clone https://github.com/sauravkhanalgit/arb_translator.git
cd arb_translator
dart pub get

# Run tests
dart test

# Static analysis (should be clean)
dart analyze

# Run the CLI locally
dart run bin/arb_translator.dart --help
```

---

## 🤝 Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Make your changes and add tests
4. Run `dart test && dart analyze`
5. Open a pull request

Please open an issue first for significant changes.

---

## 📄 License

MIT — see [LICENSE](LICENSE).

---

**Made with ❤️ for the Flutter community.**  
Star ⭐ the repo if it saves you time!
