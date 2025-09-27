# ARB Translator Gen Z 🌍

[![pub package](https://img.shields.io/pub/v/arb_translator_gen_z.svg)](https://pub.dev/packages/arb_translator_gen_z)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/arb_translator_gen_z)](https://pub.dev/packages/arb_translator_gen_z)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A **modern, robust** Dart CLI tool that automatically translates your `.arb` (Application Resource Bundle) files into multiple languages with **enterprise-grade features**. Perfect for Flutter internationalization (i18n) projects that need reliable, scalable translation workflows.

## 🎯 Why Choose ARB Translator Gen Z?

- **🚀 Next-Generation Performance**: Advanced retry logic, rate limiting, and concurrent processing
- **🛡️ Enterprise Reliability**: Comprehensive error handling, validation, and logging
- **⚙️ Highly Configurable**: YAML-based configuration system with sensible defaults
- **🧠 Intelligent Features**: Auto-detection, validation, suggestions, and batch processing
- **🌐 Comprehensive Language Support**: 100+ languages with native name display
- **📊 Detailed Reporting**: Progress indicators, success/failure tracking, and detailed logs
- **🔧 Developer Friendly**: Rich CLI interface, backup options, and validation tools

---

## ✨ Key Features

### Core Translation Features
- **Multi-language batch translation** with intelligent throttling
- **Automatic retry logic** with exponential backoff for reliable API calls
- **Rate limiting** to prevent API abuse and ensure stable operation
- **Concurrent processing** with configurable limits for optimal performance
- **Smart validation** of ARB files before and after translation
- **Metadata preservation** with automatic `@@locale` updates

### Advanced Configuration
- **YAML-based configuration** with environment-specific settings
- **Customizable API endpoints** for enterprise translation services
- **Flexible logging levels** (debug, info, warning, error)
- **Backup and recovery** options for safe file operations
- **Output formatting** control (pretty-print, compression)

### Developer Experience
- **Rich CLI interface** with helpful commands and options
- **Comprehensive error messages** with suggestions for fixes
- **Progress indicators** for long-running operations
- **Validation-only mode** for CI/CD pipelines
- **Language suggestions** for typos and similar codes
- **Popular language presets** for quick setup

---

## 🚀 Installation

### Global CLI Installation (Recommended)
```bash
dart pub global activate arb_translator_gen_z
```

After activation, you can use the tool directly:
```bash
arb_translator --help
```

### As a Project Dependency
Add to your `pubspec.yaml`:
```yaml
dependencies:
  arb_translator_gen_z: ^2.0.0
```

Then run:
```bash
dart pub get
```

**Verify your installation:**
```bash
# Check if the package is properly installed
dart pub deps

# Test the CLI locally (from your project directory)
dart run arb_translator_gen_z:arb_translator --help

# Or run programmatically
dart run -e "import 'package:arb_translator_gen_z/arb_translator_gen_z.dart'; void main() => print('Package loaded successfully!');"
```

---

## 🎮 Quick Start

> **📌 Important**: These examples show both global installation and project dependency usage.

### 1. Translate to Specific Languages

**If installed globally:**
```bash
# Translate to French and Spanish
arb_translator -s lib/l10n/app_en.arb -l fr es

# Translate to popular languages
arb_translator -s lib/l10n/app_en.arb -l fr es de it pt ru ja ko zh
```

**If using as project dependency:**
```bash
# Translate to French and Spanish
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es

# Translate to popular languages
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es de it pt ru ja ko zh
```

### 2. Translate to All Supported Languages

**Global:**
```bash
arb_translator -s lib/l10n/app_en.arb -l all
```

**Project dependency:**
```bash
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l all
```

### 3. Generate and Use Custom Configuration

**Global:**
```bash
# Create configuration file
arb_translator --init-config

# Use custom configuration
arb_translator -s lib/l10n/app_en.arb -l fr es --config my_config.yaml
```

**Project dependency:**
```bash
# Create configuration file
dart run arb_translator_gen_z:arb_translator --init-config

# Use custom configuration
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es --config my_config.yaml
```

### 4. Validate ARB Files

**Global:**
```bash
# Validate without translating (great for CI/CD)
arb_translator -s lib/l10n/app_en.arb --validate-only
```

**Project dependency:**
```bash
# Validate without translating (great for CI/CD)
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb --validate-only
```

### 5. Flutter Project Integration

**Step-by-step setup for Flutter projects:**

1. **Add the dependency to your Flutter project:**
   ```bash
   flutter pub add arb_translator_gen_z
   ```

2. **Create your ARB directory structure:**
   ```bash
   mkdir -p lib/l10n
   ```

3. **Create your source ARB file in your preferred location:**

   **Option A: Standard Flutter location (`lib/l10n/app_en.arb`):**
   ```json
   {
     "@@locale": "en",
     "hello": "Hello",
     "@hello": {
       "description": "A greeting"
     },
     "welcome": "Welcome to our app!",
     "@welcome": {
       "description": "Welcome message"
     }
   }
   ```

   **Option B: Assets directory (`assets/l10n/app_en.arb`):**
   ```bash
   # Create assets directory structure
   mkdir -p assets/l10n
   ```
   ```json
   {
     "@@locale": "en",
     "appName": "My Flutter App",
     "@appName": {
       "description": "The name of the application"
     },
     "greeting": "Hello, World!",
     "@greeting": {
       "description": "A simple greeting"
     }
   }
   ```

4. **Translate using CLI (works with any path):**
   ```bash
   # For lib/l10n/ (standard)
   dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es de
   
   # For assets/l10n/ (alternative)
   dart run arb_translator_gen_z:arb_translator -s assets/l10n/app_en.arb -l fr es de
   
   # For custom paths
   dart run arb_translator_gen_z:arb_translator -s path/to/your/strings_en.arb -l fr es de
   ```

5. **Or use programmatically in your Flutter app:**
   ```dart
   import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
   
   Future<void> translateAppStrings() async {
     const config = TranslatorConfig();
     final logger = TranslatorLogger()..initialize(config.logLevel);
     final translator = ArbTranslator(config);
     
     try {
       // For assets/l10n/ directory
       await translator.generateMultipleLanguages(
         'assets/l10n/app_en.arb',
         ['fr', 'es', 'de'],
       );
       
       // Or for lib/l10n/ directory
       await translator.generateMultipleLanguages(
         'lib/l10n/app_en.arb',
         ['fr', 'es', 'de'],
       );
       
       print('Translation completed!');
     } finally {
       translator.dispose();
     }
   }
   ```

### 6. Troubleshooting Installation

**If the `arb_translator` command is not found after global installation:**
```bash
# Ensure Dart's global packages are in your PATH
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc

# Or for bash users
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify the installation
arb_translator --help
```

**If using as a project dependency:**
```bash
# Use the full command with dart run
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr

# Or create a shortcut script in your project
echo '#!/bin/bash\ndart run arb_translator_gen_z:arb_translator "$@"' > arb_translate.sh
chmod +x arb_translate.sh
./arb_translate.sh -s lib/l10n/app_en.arb -l fr
```

**Common Flutter project issues:**
```bash
# If you get "Could not find file" errors
flutter clean
flutter pub get
dart run arb_translator_gen_z:arb_translator --help

# If imports fail in Dart code
flutter pub deps  # Check if package is properly installed
dart pub get      # Re-resolve dependencies

# Create a simple test file to verify installation
echo 'import "package:arb_translator_gen_z/arb_translator_gen_z.dart"; void main() => print("Package works!");' > test_import.dart
dart run test_import.dart
rm test_import.dart
```

**Different ARB file locations:**
```bash
# Standard Flutter i18n location
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es

# Assets directory (common alternative)
dart run arb_translator_gen_z:arb_translator -s assets/l10n/app_en.arb -l fr es

# Custom directory structure
dart run arb_translator_gen_z:arb_translator -s i18n/locales/en.arb -l fr es

# Relative paths work from project root
dart run arb_translator_gen_z:arb_translator -s ./assets/i18n/strings_en.arb -l fr es

# Check if your ARB file exists first
ls -la assets/l10n/app_en.arb  # Should show your file
```

---

## 📋 CLI Reference

### Commands
| Command | Description |
|---------|-------------|
| `--help, -h` | Show detailed help message |
| `--init-config` | Generate default configuration file |
| `--list-languages` | Show all supported languages |
| `--popular` | Show popular language codes |
| `--validate-only` | Validate ARB file without translating |

### Options
| Option | Description | Example |
|--------|-------------|---------|
| `--source, -s` | Source ARB file path | `-s lib/l10n/app_en.arb` |
| `--languages, -l` | Target language codes | `-l fr es de` or `-l all` |
| `--config, -c` | Configuration file path | `-c config.yaml` |
| `--overwrite` | Overwrite existing files | `--overwrite` (default: true) |
| `--verbose, -v` | Enable debug logging | `-v` |
| `--quiet, -q` | Suppress non-error output | `-q` |

### Examples

**Global installation:**
```bash
# Basic usage
arb_translator -s lib/l10n/app_en.arb -l fr es de

# With custom config and verbose output
arb_translator -s app_en.arb -l all --config prod_config.yaml --verbose

# Validate only (useful in CI/CD)
arb_translator -s app_en.arb --validate-only --quiet

# Show language information
arb_translator --list-languages
arb_translator --popular
```

**Project dependency:**
```bash
# Basic usage
dart run arb_translator_gen_z:arb_translator -s lib/l10n/app_en.arb -l fr es de

# With custom config and verbose output
dart run arb_translator_gen_z:arb_translator -s app_en.arb -l all --config prod_config.yaml --verbose

# Validate only (useful in CI/CD)
dart run arb_translator_gen_z:arb_translator -s app_en.arb --validate-only --quiet

# Show language information
dart run arb_translator_gen_z:arb_translator --list-languages
dart run arb_translator_gen_z:arb_translator --popular
```

---

## ⚙️ Configuration

### Configuration File Structure
Generate a default configuration file:
```bash
arb_translator --init-config
```

This creates `~/.arb_translator/config.yaml` with comprehensive settings:

```yaml
# Translation settings
maxConcurrentTranslations: 5
retryAttempts: 3
retryDelayMs: 1000
requestTimeoutMs: 30000
rateLimitDelayMs: 100
sourceLanguage: "auto"

# Output settings
preserveMetadata: true
prettyPrintJson: true
backupOriginal: false
validateOutput: true

# Logging
logLevel: "info"  # debug, info, warning, error

# API settings (optional)
# customApiEndpoint: "https://custom-api.example.com"
```

### Configuration Options

| Setting | Description | Default | Options |
|---------|-------------|---------|---------|
| `maxConcurrentTranslations` | Max parallel requests | `5` | `1-20` |
| `retryAttempts` | Max retry attempts | `3` | `0-10` |
| `retryDelayMs` | Delay between retries | `1000` | `100-10000` |
| `requestTimeoutMs` | Request timeout | `30000` | `5000-120000` |
| `rateLimitDelayMs` | Delay between requests | `100` | `0-5000` |
| `sourceLanguage` | Source language detection | `"auto"` | Any language code |
| `preserveMetadata` | Keep ARB metadata | `true` | `true/false` |
| `prettyPrintJson` | Format JSON output | `true` | `true/false` |
| `backupOriginal` | Create backup files | `false` | `true/false` |
| `validateOutput` | Validate generated files | `true` | `true/false` |
| `logLevel` | Logging verbosity | `"info"` | `debug/info/warning/error` |

---

## � Supported Languages

The tool supports **100+ languages** with comprehensive metadata:

### Popular Languages (Quick Reference)
```
English (en)     Español (es)      Français (fr)     Deutsch (de)
Italiano (it)    Português (pt)    Русский (ru)      日本語 (ja)
한국어 (ko)        中文 (zh)          العربية (ar)       हिन्दी (hi)
Nederlands (nl)  Svenska (sv)      Dansk (da)        Norsk (no)
```

### View All Languages
```bash
# Show all supported languages with native names
arb_translator --list-languages

# Show popular languages only
arb_translator --popular
```

### Language Features
- **Native names** displayed for better user experience
- **Right-to-left (RTL) language detection** for proper handling
- **Language suggestions** for typos and similar codes
- **Regional variants** support (e.g., `zh-cn`, `zh-tw`)

---

## 🔧 Programmatic Usage

### Basic Translation
```dart
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> translateFiles() async {
  try {
    // Load default configuration (or create one)
    final config = await TranslatorConfig.fromFile() ?? const TranslatorConfig();
    
    // Initialize logger (required)
    final logger = TranslatorLogger();
    logger.initialize(config.logLevel);
    
    // Create translator
    final translator = ArbTranslator(config);
    
    // Translate to single language
    final outputPath = await translator.generateArbForLanguage(
      'lib/l10n/app_en.arb',
      'fr',
    );
    print('Translation completed: $outputPath');
    
    // Translate to multiple languages
    await translator.generateMultipleLanguages(
      'lib/l10n/app_en.arb',
      ['fr', 'es', 'de', 'it'],
    );
    
    // Clean up
    translator.dispose();
  } catch (e) {
    print('Translation failed: $e');
  }
}
```

### Quick Start for Dependency Users
```dart
// Simple one-liner translation function
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

/// Translate an ARB file to a target language
Future<String> translateArb(String sourcePath, String targetLang) async {
  const config = TranslatorConfig();
  final logger = TranslatorLogger()..initialize(config.logLevel);
  final translator = ArbTranslator(config);
  
  try {
    return await translator.generateArbForLanguage(sourcePath, targetLang);
  } finally {
    translator.dispose();
  }
}

void main() async {
  // Use the helper function
  try {
    final result = await translateArb('assets/i18n/app_en.arb', 'es');
    print('✅ Translation completed: $result');
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

### Complete Example with Error Handling
```dart
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';

Future<void> completeExample() async {
  try {
    // Load or create configuration
    final config = await TranslatorConfig.fromFile() ?? const TranslatorConfig();
    
    // Initialize logger
    final logger = TranslatorLogger();
    logger.initialize(config.logLevel);
    
    // Create translator
    final translator = ArbTranslator(config);
    
    // Translate to multiple languages
    final results = await translator.generateMultipleLanguages(
      'lib/l10n/app_en.arb',
      ['fr', 'es', 'de', 'it'],
    );
    
    // Show results
    results.forEach((lang, path) {
      final info = getLanguageInfo(lang);
      print('✅ ${info?.nativeName ?? lang}: $path');
    });
    
    translator.dispose();
  } catch (e) {
    print('❌ Translation failed: $e');
  }
}
```

### Custom Configuration
```dart
import 'package:arb_translator_gen_z/src/config/translator_config.dart';

// Create custom configuration
final customConfig = TranslatorConfig(
  maxConcurrentTranslations: 3,
  retryAttempts: 5,
  logLevel: LogLevel.debug,
  prettyPrintJson: true,
  validateOutput: true,
);

final translator = ArbTranslator(customConfig);
```

### Advanced Features
```dart
import 'package:arb_translator_gen_z/arb_helper.dart';
import 'package:arb_translator_gen_z/languages.dart';

// Validate ARB files
final content = await ArbHelper.readArbFile('app_en.arb');
final issues = ArbHelper.validateArbContent(content);

if (issues.isNotEmpty) {
  print('Validation issues: $issues');
}

// Language utilities
final info = getLanguageInfo('fr');
print('${info?.name}: ${info?.nativeName}'); // French: Français

final suggestions = suggestLanguageCodes('fren');
print('Did you mean: $suggestions'); // [fr]
```

---

## 🛠️ Development and Testing

### Setting Up Development Environment
```bash
git clone https://github.com/sauravkhanalgit/arb_translator.git
cd arb_translator
dart pub get
```

### Running Tests
```bash
# Run all tests
dart test

# Run tests with coverage
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

### Linting and Analysis
```bash
# Run static analysis
dart analyze

# Check formatting
dart format --set-exit-if-changed lib/ bin/ test/

# Run all checks
dart pub run very_good_analysis
```

---

## 📈 Performance and Reliability

### Performance Features
- **Concurrent processing**: Configurable parallel translation requests
- **Intelligent batching**: Automatic request grouping for optimal throughput
- **Rate limiting**: Prevents API throttling and ensures stable operation
- **Retry logic**: Exponential backoff for handling temporary failures
- **Caching**: Reduces redundant API calls for repeated translations

### Reliability Features
- **Comprehensive error handling**: Specific exception types with detailed messages
- **Input validation**: Pre-flight checks for ARB file format and language codes
- **Output validation**: Post-processing verification of generated files
- **Backup options**: Safe file operations with rollback capabilities
- **Logging system**: Detailed operation tracking for debugging and monitoring

### Benchmarks
On typical hardware with a stable internet connection:
- **Single language**: ~2-5 seconds for 50 strings
- **10 languages**: ~15-30 seconds for 50 strings each
- **All languages (100+)**: ~5-10 minutes for 50 strings each

*Performance varies based on API response times, network conditions, and translation complexity.*

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Quick Contribution Guide
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run tests and linting (`dart test && dart analyze`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Create a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Google Translate API for translation services
- The Flutter team for ARB file format specifications
- The Dart community for excellent tooling and packages

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/sauravkhanalgit/arb_translator/issues)
- **Documentation**: [GitHub Wiki](https://github.com/sauravkhanalgit/arb_translator/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/sauravkhanalgit/arb_translator/discussions)

---

## 🔮 Roadmap

- [ ] **Custom Translation APIs**: Support for Azure Translator, AWS Translate, etc.
- [ ] **Translation Memory**: Cache and reuse previous translations
- [ ] **Batch File Processing**: Handle multiple ARB files in one command
- [ ] **CI/CD Integration**: GitHub Actions and other workflow integrations
- [ ] **GUI Application**: Desktop application for non-technical users
- [ ] **Translation Quality Scoring**: AI-powered translation quality assessment
- [ ] **Collaborative Features**: Team translation workflows and review processes

---

**Made with ❤️ for the Flutter community**

*Star ⭐ this repo if you find it useful!*
 