# Changelog

## 1.0.0
- Initial release
- Adds ARB reading, writing, and translation functionality

## 1.0.1
- Quality Check

## 1.0.2
- Quality improvement

## 2.0.0

### 🎉 Major Release - Complete Rewrite with Enterprise Features

This is a complete rewrite of ARB Translator with modern architecture and enterprise-grade features.

#### ✨ New Features
- **Advanced Configuration System**: YAML-based configuration with comprehensive settings
- **Intelligent Logging**: Structured logging with multiple levels and colored output
- **Enhanced Error Handling**: Custom exception types with detailed error messages
- **Batch Translation**: Concurrent processing with configurable limits
- **Retry Logic**: Exponential backoff for robust API communication
- **Rate Limiting**: Intelligent request throttling to prevent API abuse
- **ARB Validation**: Comprehensive validation before and after translation
- **Language Intelligence**: 100+ languages with native names and RTL detection
- **Backup System**: Optional file backup before overwriting
- **Progress Indicators**: Real-time progress tracking for long operations
- **CLI Enhancements**: Rich command-line interface with helpful commands

#### 🛠️ Technical Improvements
- **Modern Dart**: Updated to Dart 3.2+ with latest best practices
- **Comprehensive Linting**: Very Good Analysis for code quality
- **Better Testing**: Extensive test coverage with mock support
- **Documentation**: Complete API documentation and examples
- **Type Safety**: Full null safety with strict typing
- **Performance**: Optimized concurrent processing and memory usage

#### 🔧 Breaking Changes
- **API Changes**: New class-based API (legacy functions deprecated but available)
- **Configuration**: New configuration system (old behavior available as defaults)
- **CLI Options**: Enhanced CLI with new options (old usage still supported)
- **Dependencies**: Updated minimum Dart SDK to 3.2.0

#### 📚 New CLI Commands
- `--init-config`: Generate configuration file
- `--list-languages`: Show all supported languages with native names  
- `--popular`: Show popular language codes
- `--validate-only`: Validate ARB files without translation
- `--verbose`: Debug logging
- `--quiet`: Minimal output

#### 🌐 Language Support
- **Native Names**: All languages display with native names
- **RTL Detection**: Automatic right-to-left language identification
- **Language Suggestions**: Smart suggestions for typos
- **Popular Presets**: Curated list of commonly used languages

#### 🔬 Developer Experience
- **Rich Exceptions**: Detailed error messages with suggestions
- **Validation Tools**: Pre-flight checks and post-processing validation  
- **Progress Tracking**: Visual progress indicators
- **Comprehensive Logging**: Detailed operation logs for debugging
- **Configuration Validation**: YAML configuration with validation

#### 📈 Performance Improvements
- **Concurrent Processing**: Configurable parallel translation requests
- **Smart Batching**: Intelligent request grouping
- **Memory Optimization**: Efficient memory usage for large files
- **Connection Pooling**: HTTP client optimization

#### 🛡️ Reliability Features  
- **Input Validation**: Comprehensive ARB file validation
- **Output Verification**: Generated file validation
- **Backup Options**: Safe file operations with rollback
- **Error Recovery**: Graceful handling of API failures
- **Rate Limiting**: Prevents API throttling

### Migration Guide
See README.md for detailed migration instructions from v1.x to v2.0.

## 1.0.3
- updated example