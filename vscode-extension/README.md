# ARB Translator Gen Z - VS Code Extension

AI-powered ARB file translation with real-time validation and IntelliSense support for Flutter internationalization.

## Features

### 🚀 AI-Powered Translation
- **5 AI Providers**: OpenAI GPT, DeepL, Azure Translator, AWS Translate, Google Translate
- **Context-Aware**: Uses ARB description fields for accurate translations
- **Quality Scoring**: Automatic quality assessment and suggestions
- **Smart Fallbacks**: Intelligent provider selection and failover

### 🔍 Real-Time Validation
- **ARB Schema Validation**: JSON schema validation for ARB files
- **Missing Keys Detection**: Automatically detect untranslated keys
- **Placeholder Consistency**: Validate placeholder usage across languages
- **Live Diagnostics**: Real-time error and warning display

### 💡 IntelliSense & Snippets
- **ARB-Specific IntelliSense**: Smart completions for ARB files
- **Code Snippets**: Pre-built snippets for common ARB patterns
- **Placeholder Help**: Context-sensitive placeholder suggestions
- **ICU Message Support**: IntelliSense for complex pluralization

### 📊 Analytics Dashboard
- **Translation Metrics**: Track translation success rates and costs
- **Quality Trends**: Monitor translation quality over time
- **Provider Performance**: Compare AI provider performance
- **Project Statistics**: Overview of translation completeness

## Installation

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "ARB Translator Gen Z"
4. Click Install

## Configuration

Configure the extension through VS Code settings:

```json
{
  "arbTranslator.preferredProvider": "openai",
  "arbTranslator.targetLanguages": ["es", "fr", "de"],
  "arbTranslator.enableRealTimeValidation": true,
  "arbTranslator.enableIntelliSense": true,
  "arbTranslator.cliPath": "arb_translator"
}
```

### Settings Explained

- **`preferredProvider`**: Default AI translation provider
- **`targetLanguages`**: Default languages for batch translation
- **`enableRealTimeValidation`**: Enable live ARB file validation
- **`enableIntelliSense`**: Enable ARB-specific IntelliSense features
- **`cliPath`**: Path to ARB Translator CLI (if not in PATH)

## Usage

### Commands

Access all features through the Command Palette (Ctrl+Shift+P):

- **`ARB: Translate File`**: Translate selected ARB file to multiple languages
- **`ARB: Validate File`**: Validate ARB file for issues
- **`ARB: Analyze Project`**: Analyze all ARB files in workspace
- **`ARB: Show Analytics Dashboard`**: Display translation analytics

### Context Menu

Right-click on ARB files in the Explorer to access:
- Translate File
- Validate File

### Language Selection

When translating, select target languages from a quick-pick menu. Popular languages include:
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Portuguese (pt)
- Russian (ru)
- Japanese (ja)
- Korean (ko)
- Chinese (zh)
- Arabic (ar)

### Snippets

Use these snippets in ARB files:

- `arb-template`: Complete ARB file template
- `arb-entry`: Simple translation entry
- `arb-placeholder`: Translation with placeholder
- `arb-plural`: ICU pluralization message
- `arb-datetime`: Date/time formatting
- `arb-currency`: Currency formatting
- `arb-error`: Error message
- `arb-button`: Button text
- `arb-nav`: Navigation item

## Real-Time Features

### Live Validation
- Invalid JSON syntax highlighting
- Missing `@@locale` warnings
- Empty translation value warnings
- Placeholder consistency checks

### IntelliSense Support
- ARB key completion
- Placeholder suggestions
- ICU message pattern help
- Context-aware descriptions

## Requirements

- **ARB Translator CLI**: Install the main CLI tool
- **VS Code**: Version 1.74.0 or higher
- **Node.js**: For extension development (optional)

## API Keys Setup

Configure API keys for AI providers in your environment or ARB Translator config:

```bash
# OpenAI
export ARB_OPENAI_API_KEY="your-key"

# DeepL
export ARB_DEEPL_API_KEY="your-key"

# Azure Translator
export ARB_AZURE_KEY="your-key"
export ARB_AZURE_REGION="your-region"

# AWS Translate
export ARB_AWS_ACCESS_KEY_ID="your-key"
export ARB_AWS_SECRET_ACCESS_KEY="your-secret"
export ARB_AWS_REGION="your-region"

# Google Translate
export ARB_GOOGLE_API_KEY="your-key"
```

## Troubleshooting

### CLI Not Found
If the extension can't find the CLI:
1. Install ARB Translator CLI
2. Add to PATH, or
3. Set `arbTranslator.cliPath` in settings

### Validation Not Working
Check that `enableRealTimeValidation` is enabled in settings.

### Translation Fails
1. Verify API keys are configured
2. Check internet connection
3. Try different AI provider in settings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Changelog

### v3.2.0
- Initial VS Code extension release
- AI-powered translation integration
- Real-time ARB validation
- IntelliSense support
- Analytics dashboard
- ARB snippets and schema validation

---

**Made with ❤️ for Flutter developers worldwide**
