/// Custom exceptions for translation operations.
library translation_exceptions;

/// Base exception class for all translation-related errors.
abstract class TranslationException implements Exception {
  /// Creates a [TranslationException] with an optional [message].
  const TranslationException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'TranslationException: $message';
}

/// Exception thrown when a language code is not supported.
class UnsupportedLanguageException extends TranslationException {
  /// Creates an [UnsupportedLanguageException] for the given [languageCode].
  const UnsupportedLanguageException(this.languageCode)
      : super('Unsupported language code: $languageCode');

  /// The unsupported language code.
  final String languageCode;

  @override
  String toString() =>
      'UnsupportedLanguageException: Language code "$languageCode" is not supported';
}

/// Exception thrown when a translation API call fails.
class TranslationApiException extends TranslationException {
  /// Creates a [TranslationApiException] with the given [statusCode] and optional [details].
  const TranslationApiException(this.statusCode, [this.details])
      : super('Translation API failed with status code: $statusCode');

  /// The HTTP status code returned by the translation API.
  final int statusCode;

  /// Additional details about the API failure.
  final String? details;

  @override
  String toString() {
    final baseMessage =
        'TranslationApiException: API call failed with status $statusCode';
    return details != null ? '$baseMessage - $details' : baseMessage;
  }
}

/// Exception thrown when translation rate limit is exceeded.
class TranslationRateLimitException extends TranslationException {
  /// Creates a [TranslationRateLimitException] with optional [retryAfter] seconds.
  const TranslationRateLimitException([this.retryAfter])
      : super('Translation rate limit exceeded');

  /// Number of seconds to wait before retrying, if provided by the API.
  final int? retryAfter;

  @override
  String toString() {
    const baseMessage = 'TranslationRateLimitException: Rate limit exceeded';
    return retryAfter != null
        ? '$baseMessage, retry after ${retryAfter}s'
        : baseMessage;
  }
}

/// Exception thrown when translation text is invalid or empty.
class InvalidTranslationTextException extends TranslationException {
  /// Creates an [InvalidTranslationTextException] for the given [text] and [reason].
  const InvalidTranslationTextException(this.text, this.reason)
      : super('Invalid translation text: $reason');

  /// The invalid text that was provided for translation.
  final String text;

  /// The reason why the text is invalid.
  final String reason;

  @override
  String toString() =>
      'InvalidTranslationTextException: $reason for text: "$text"';
}

/// Exception thrown when translation service is temporarily unavailable.
class TranslationServiceUnavailableException extends TranslationException {
  /// Creates a [TranslationServiceUnavailableException] with optional [retryAfter] seconds.
  const TranslationServiceUnavailableException([this.retryAfter])
      : super('Translation service temporarily unavailable');

  /// Number of seconds to wait before retrying.
  final int? retryAfter;

  @override
  String toString() {
    const baseMessage =
        'TranslationServiceUnavailableException: Service unavailable';
    return retryAfter != null
        ? '$baseMessage, retry after ${retryAfter}s'
        : baseMessage;
  }
}
