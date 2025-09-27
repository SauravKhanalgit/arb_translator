/// Custom exceptions for ARB file operations.
library arb_exceptions;

/// Base exception class for all ARB-related errors.
abstract class ArbException implements Exception {
  /// Creates an [ArbException] with an optional [message].
  const ArbException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'ArbException: $message';
}

/// Exception thrown when an ARB file cannot be found.
class ArbFileNotFoundException extends ArbException {
  /// Creates an [ArbFileNotFoundException] for the given [filePath].
  const ArbFileNotFoundException(this.filePath)
      : super('ARB file not found: $filePath');

  /// The path to the file that could not be found.
  final String filePath;

  @override
  String toString() =>
      'ArbFileNotFoundException: ARB file not found at $filePath';
}

/// Exception thrown when an ARB file has invalid JSON format.
class ArbFileFormatException extends ArbException {
  /// Creates an [ArbFileFormatException] for the given [filePath] and [details].
  const ArbFileFormatException(this.filePath, this.details)
      : super('Invalid ARB file format: $filePath - $details');

  /// The path to the invalid ARB file.
  final String filePath;

  /// Additional details about the format error.
  final String details;

  @override
  String toString() =>
      'ArbFileFormatException: Invalid format in $filePath - $details';
}

/// Exception thrown when an ARB file cannot be written.
class ArbFileWriteException extends ArbException {
  /// Creates an [ArbFileWriteException] for the given [filePath] and [reason].
  const ArbFileWriteException(this.filePath, this.reason)
      : super('Failed to write ARB file: $filePath - $reason');

  /// The path to the file that could not be written.
  final String filePath;

  /// The reason why the write operation failed.
  final String reason;

  @override
  String toString() =>
      'ArbFileWriteException: Failed to write $filePath - $reason';
}

/// Exception thrown when ARB file validation fails.
class ArbValidationException extends ArbException {
  /// Creates an [ArbValidationException] for the given [filePath] and [issues].
  const ArbValidationException(this.filePath, this.issues)
      : super('ARB validation failed: $filePath');

  /// The path to the ARB file that failed validation.
  final String filePath;

  /// List of validation issues found.
  final List<String> issues;

  @override
  String toString() =>
      'ArbValidationException: Validation failed for $filePath\n'
      'Issues: ${issues.join(', ')}';
}
