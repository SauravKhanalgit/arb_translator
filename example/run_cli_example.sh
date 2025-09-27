#!/bin/bash
# ARB Translator Gen Z - CLI Usage Examples
# This script demonstrates various ways to use the ARB translator CLI

set -e  # Exit on any error

echo "🌍 ARB Translator Gen Z - CLI Examples"
echo "======================================"

# Source ARB file path
SOURCE_FILE="lib/l10n/app_en.arb"

# Check if source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "❌ Source file not found: $SOURCE_FILE"
    echo "Please create an ARB file or update the SOURCE_FILE path"
    exit 1
fi

echo "✅ Using source file: $SOURCE_FILE"
echo ""

# Example 1: Show help
echo "📖 Example 1: Show help information"
echo "Command: arb_translator --help"
arb_translator --help
echo ""

# Example 2: Validate ARB file
echo "🔍 Example 2: Validate ARB file without translating"
echo "Command: arb_translator -s $SOURCE_FILE --validate-only"
arb_translator -s "$SOURCE_FILE" --validate-only
echo ""

# Example 3: Show popular languages
echo "🌟 Example 3: Show popular language codes"
echo "Command: arb_translator --popular"
arb_translator --popular
echo ""

# Example 4: Single language translation
echo "🇫🇷 Example 4: Translate to French"
echo "Command: arb_translator -s $SOURCE_FILE -l fr"
arb_translator -s "$SOURCE_FILE" -l fr
echo ""

# Example 5: Multiple language translation
echo "🌍 Example 5: Translate to multiple languages"
echo "Command: arb_translator -s $SOURCE_FILE -l \"es de it\""
arb_translator -s "$SOURCE_FILE" -l "es de it"
echo ""

# Example 6: Translation with verbose logging
echo "🔬 Example 6: Translate with verbose logging"
echo "Command: arb_translator -s $SOURCE_FILE -l pt --verbose"
arb_translator -s "$SOURCE_FILE" -l pt --verbose
echo ""

# Example 7: Generate configuration file
echo "⚙️ Example 7: Generate configuration file"
echo "Command: arb_translator --init-config"
arb_translator --init-config
echo ""

# Example 8: Use custom configuration (if config exists)
CONFIG_FILE="$HOME/.arb_translator/config.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "📋 Example 8: Use custom configuration"
    echo "Command: arb_translator -s $SOURCE_FILE -l ru --config $CONFIG_FILE"
    arb_translator -s "$SOURCE_FILE" -l ru --config "$CONFIG_FILE"
    echo ""
fi

# Example 9: Popular languages batch translation
echo "🚀 Example 9: Translate to popular languages (first 5)"
echo "Command: arb_translator -s $SOURCE_FILE -l \"fr es de it pt\""
arb_translator -s "$SOURCE_FILE" -l "fr es de it pt"
echo ""

# Example 10: Show all supported languages (first 20 lines)
echo "📚 Example 10: Show supported languages (first 20)"
echo "Command: arb_translator --list-languages | head -20"
arb_translator --list-languages | head -20
echo "... (and many more)"
echo ""

echo "✅ All examples completed successfully!"
echo ""
echo "💡 Tips:"
echo "- Use quotes around multiple language codes: \"fr es de\""
echo "- Use --verbose for detailed logging during translation"
echo "- Use --validate-only to check ARB files without translating"
echo "- Use --init-config to create a custom configuration file"
echo "- Use --quiet to suppress output except errors"
echo ""
echo "📖 For more information, visit:"
echo "   https://github.com/sauravkhanalgit/arb_translator"