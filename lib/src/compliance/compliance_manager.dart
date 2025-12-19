import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';
import 'package:crypto/crypto.dart';

/// Audit log entry for compliance tracking.
class AuditEntry {
  /// Creates an [AuditEntry] with the given parameters.
  const AuditEntry({
    required this.timestamp,
    required this.action,
    required this.userId,
    required this.resource,
    required this.details,
    required this.ipAddress,
    required this.userAgent,
    this.sessionId,
    this.confidential = false,
  });

  /// Timestamp of the action.
  final DateTime timestamp;

  /// Action performed (create, read, update, delete, translate, etc.).
  final String action;

  /// User identifier (anonymized for GDPR).
  final String userId;

  /// Resource affected (file path, translation key, etc.).
  final String resource;

  /// Detailed information about the action.
  final Map<String, dynamic> details;

  /// IP address (anonymized for GDPR).
  final String ipAddress;

  /// User agent string.
  final String userAgent;

  /// Session identifier.
  final String? sessionId;

  /// Whether this entry contains confidential information.
  final bool confidential;

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'userId': userId,
    'resource': resource,
    'details': details,
    'ipAddress': _anonymizeIp(ipAddress),
    'userAgent': userAgent,
    'sessionId': sessionId,
    'confidential': confidential,
  };

  /// Create from JSON.
  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    timestamp: DateTime.parse(json['timestamp']),
    action: json['action'],
    userId: json['userId'],
    resource: json['resource'],
    details: json['details'] as Map<String, dynamic>,
    ipAddress: json['ipAddress'],
    userAgent: json['userAgent'],
    sessionId: json['sessionId'],
    confidential: json['confidential'] ?? false,
  );

  /// Anonymize IP address for GDPR compliance.
  static String _anonymizeIp(String ip) {
    if (ip.contains('.')) {
      // IPv4: mask last octet
      final parts = ip.split('.');
      if (parts.length == 4) {
        return '${parts[0]}.${parts[1]}.${parts[2]}.xxx';
      }
    } else if (ip.contains(':')) {
      // IPv6: mask last 64 bits
      final parts = ip.split(':');
      if (parts.length == 8) {
        return '${parts.sublist(0, 4).join(':')}:xxxx:xxxx:xxxx:xxxx';
      }
    }
    return 'xxx.xxx.xxx.xxx'; // Fallback
  }

  @override
  String toString() => '[$timestamp] $action by $userId on $resource';
}

/// Data retention policy configuration.
class RetentionPolicy {
  /// Creates a [RetentionPolicy] with the given parameters.
  const RetentionPolicy({
    required this.dataType,
    required this.retentionPeriod,
    required this.deletionMethod,
    this.autoDelete = true,
    this.complianceFrameworks = const [],
  });

  /// Type of data (audit_logs, translations, user_data, etc.).
  final String dataType;

  /// Retention period in days.
  final int retentionPeriod;

  /// Method for deletion (delete, archive, anonymize).
  final String deletionMethod;

  /// Whether to automatically delete old data.
  final bool autoDelete;

  /// Compliance frameworks this applies to (GDPR, CCPA, etc.).
  final List<String> complianceFrameworks;

  /// Check if data is expired based on this policy.
  bool isExpired(DateTime dataTimestamp) {
    final expiryDate = dataTimestamp.add(Duration(days: retentionPeriod));
    return DateTime.now().isAfter(expiryDate);
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'dataType': dataType,
    'retentionPeriod': retentionPeriod,
    'deletionMethod': deletionMethod,
    'autoDelete': autoDelete,
    'complianceFrameworks': complianceFrameworks,
  };

  /// Create from JSON.
  factory RetentionPolicy.fromJson(Map<String, dynamic> json) => RetentionPolicy(
    dataType: json['dataType'],
    retentionPeriod: json['retentionPeriod'],
    deletionMethod: json['deletionMethod'],
    autoDelete: json['autoDelete'] ?? true,
    complianceFrameworks: List<String>.from(json['complianceFrameworks'] ?? []),
  );
}

/// Privacy settings for GDPR compliance.
class PrivacySettings {
  /// Creates [PrivacySettings] with the given parameters.
  const PrivacySettings({
    this.dataCollectionEnabled = false,
    this.analyticsEnabled = false,
    this.errorReportingEnabled = false,
    this.personalizationEnabled = false,
    this.retentionPolicies = const [],
  });

  /// Whether data collection is enabled.
  final bool dataCollectionEnabled;

  /// Whether analytics collection is enabled.
  final bool analyticsEnabled;

  /// Whether error reporting is enabled.
  final bool errorReportingEnabled;

  /// Whether personalization is enabled.
  final bool personalizationEnabled;

  /// Data retention policies.
  final List<RetentionPolicy> retentionPolicies;

  /// Get retention policy for a specific data type.
  RetentionPolicy? getPolicy(String dataType) {
    for (final policy in retentionPolicies) {
      if (policy.dataType == dataType) {
        return policy;
      }
    }
    return null;
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'dataCollectionEnabled': dataCollectionEnabled,
    'analyticsEnabled': analyticsEnabled,
    'errorReportingEnabled': errorReportingEnabled,
    'personalizationEnabled': personalizationEnabled,
    'retentionPolicies': retentionPolicies.map((p) => p.toJson()).toList(),
  };

  /// Create from JSON.
  factory PrivacySettings.fromJson(Map<String, dynamic> json) => PrivacySettings(
    dataCollectionEnabled: json['dataCollectionEnabled'] ?? false,
    analyticsEnabled: json['analyticsEnabled'] ?? false,
    errorReportingEnabled: json['errorReportingEnabled'] ?? false,
    personalizationEnabled: json['personalizationEnabled'] ?? false,
    retentionPolicies: (json['retentionPolicies'] as List<dynamic>?)
        ?.map((p) => RetentionPolicy.fromJson(p))
        .toList() ?? [],
  );

  /// Default GDPR-compliant settings.
  factory PrivacySettings.gdprCompliant() => const PrivacySettings(
    dataCollectionEnabled: false,
    analyticsEnabled: false,
    errorReportingEnabled: false,
    personalizationEnabled: false,
    retentionPolicies: [
      RetentionPolicy(
        dataType: 'audit_logs',
        retentionPeriod: 2555, // 7 years for GDPR
        deletionMethod: 'delete',
        complianceFrameworks: ['GDPR'],
      ),
      RetentionPolicy(
        dataType: 'translation_memory',
        retentionPeriod: 1825, // 5 years
        deletionMethod: 'anonymize',
        complianceFrameworks: ['GDPR'],
      ),
      RetentionPolicy(
        dataType: 'user_sessions',
        retentionPeriod: 30, // 30 days
        deletionMethod: 'delete',
        complianceFrameworks: ['GDPR'],
      ),
    ],
  );
}

/// Comprehensive compliance manager for GDPR, audit logging, and data retention.
class ComplianceManager {
  /// Creates a [ComplianceManager] with the given configuration.
  ComplianceManager({
    required this.storagePath,
    required this.logger,
    required this.privacySettings,
  }) {
    _initializeAuditLog();
    _startRetentionCleanup();
  }

  /// Path for storing compliance data.
  final String storagePath;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Privacy settings for compliance.
  final PrivacySettings privacySettings;

  /// Audit log entries.
  final List<AuditEntry> _auditLog = [];

  /// Maximum audit entries to keep in memory.
  static const int _maxInMemoryEntries = 10000;

  /// Get current audit log (read-only).
  List<AuditEntry> get auditLog => List.unmodifiable(_auditLog);

  /// Log an audit event.
  Future<void> logAuditEvent({
    required String action,
    required String userId,
    required String resource,
    required Map<String, dynamic> details,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    bool confidential = false,
  }) async {
    if (!privacySettings.dataCollectionEnabled && !confidential) {
      return; // Don't log non-confidential data if collection is disabled
    }

    final entry = AuditEntry(
      timestamp: DateTime.now(),
      action: action,
      userId: _anonymizeUserId(userId),
      resource: _sanitizeResource(resource),
      details: _sanitizeDetails(details),
      ipAddress: ipAddress ?? 'unknown',
      userAgent: userAgent ?? 'unknown',
      sessionId: sessionId,
      confidential: confidential,
    );

    _auditLog.add(entry);

    // Maintain memory limits
    if (_auditLog.length > _maxInMemoryEntries) {
      _auditLog.removeRange(0, _auditLog.length - _maxInMemoryEntries);
    }

    // Persist to disk if configured
    await _persistAuditEntry(entry);

    logger.debug('Audit logged: $action by $userId on $resource');
  }

  /// Export audit log for compliance review.
  Future<String> exportAuditLog({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? actions,
    bool includeConfidential = false,
  }) async {
    final filteredEntries = _auditLog.where((entry) {
      if (!includeConfidential && entry.confidential) return false;
      if (fromDate != null && entry.timestamp.isBefore(fromDate)) return false;
      if (toDate != null && entry.timestamp.isAfter(toDate)) return false;
      if (actions != null && !actions.contains(entry.action)) return false;
      return true;
    }).toList();

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEntries': filteredEntries.length,
      'filters': {
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
        'actions': actions,
        'includeConfidential': includeConfidential,
      },
      'entries': filteredEntries.map((e) => e.toJson()).toList(),
    };

    return json.encode(exportData);
  }

  /// Perform data retention cleanup.
  Future<int> performRetentionCleanup() async {
    var deletedCount = 0;

    for (final policy in privacySettings.retentionPolicies) {
      deletedCount += await _cleanupDataType(policy);
    }

    logger.info('Retention cleanup completed: $deletedCount items removed');
    return deletedCount;
  }

  /// Check GDPR compliance status.
  Map<String, dynamic> checkCompliance() {
    final status = <String, dynamic>{
      'gdprCompliant': true,
      'issues': <String>[],
      'recommendations': <String>[],
    };

    // Check privacy settings
    if (privacySettings.dataCollectionEnabled) {
      status['issues'].add('Data collection is enabled - ensure proper consent');
      status['gdprCompliant'] = false;
    }

    if (privacySettings.analyticsEnabled) {
      status['issues'].add('Analytics collection enabled - ensure proper consent');
      status['gdprCompliant'] = false;
    }

    // Check retention policies
    final hasGdprRetention = privacySettings.retentionPolicies
        .any((policy) => policy.complianceFrameworks.contains('GDPR'));

    if (!hasGdprRetention) {
      status['issues'].add('No GDPR-compliant retention policies configured');
      status['gdprCompliant'] = false;
    }

    // Check for long retention periods
    for (final policy in privacySettings.retentionPolicies) {
      if (policy.retentionPeriod > 2555) { // 7 years
        status['recommendations'].add(
          '${policy.dataType}: Consider reducing retention period for GDPR compliance'
        );
      }
    }

    // Check audit log
    if (_auditLog.isEmpty) {
      status['recommendations'].add('Enable audit logging for better compliance tracking');
    }

    return status;
  }

  /// Handle data deletion request (right to be forgotten).
  Future<int> deleteUserData(String userId) async {
    final anonymizedUserId = _anonymizeUserId(userId);
    var deletedCount = 0;

    // Remove from audit log
    _auditLog.removeWhere((entry) {
      if (entry.userId == anonymizedUserId) {
        deletedCount++;
        return true;
      }
      return false;
    });

    // Log the deletion
    await logAuditEvent(
      action: 'data_deletion',
      userId: 'system',
      resource: 'user_data',
      details: {'deletedUserId': anonymizedUserId, 'deletedEntries': deletedCount},
      confidential: true,
    );

    logger.info('User data deletion completed: $deletedCount entries removed for user $anonymizedUserId');
    return deletedCount;
  }

  /// Generate compliance report.
  Future<String> generateComplianceReport() async {
    final complianceStatus = checkCompliance();
    final auditStats = await _getAuditStats();

    final report = {
      'generatedAt': DateTime.now().toIso8601String(),
      'compliance': complianceStatus,
      'auditStats': auditStats,
      'privacySettings': privacySettings.toJson(),
      'dataRetention': {
        'policies': privacySettings.retentionPolicies.map((p) => p.toJson()).toList(),
        'lastCleanup': await _getLastCleanupDate(),
      },
    };

    return json.encode(report);
  }

  /// Anonymize user ID for GDPR compliance.
  String _anonymizeUserId(String userId) {
    if (!privacySettings.dataCollectionEnabled) {
      return 'anonymous';
    }

    // Create consistent hash for the same user
    final hash = sha256.convert(utf8.encode(userId)).toString();
    return 'user_${hash.substring(0, 16)}';
  }

  /// Sanitize resource path for logging.
  String _sanitizeResource(String resource) {
    // Remove sensitive information from paths
    return resource.replaceAll(RegExp(r'/users/[^/]+/'), '/users/[redacted]/');
  }

  /// Sanitize audit details.
  Map<String, dynamic> _sanitizeDetails(Map<String, dynamic> details) {
    final sanitized = Map<String, dynamic>.from(details);

    // Remove sensitive fields
    sanitized.remove('password');
    sanitized.remove('token');
    sanitized.remove('apiKey');

    // Anonymize emails
    if (sanitized.containsKey('email')) {
      sanitized['email'] = _anonymizeEmail(sanitized['email']);
    }

    return sanitized;
  }

  /// Anonymize email address.
  String _anonymizeEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email;

    final username = email.substring(0, atIndex);
    final domain = email.substring(atIndex + 1);

    if (username.length <= 2) return '${username}***@$domain';
    return '${username.substring(0, 2)}***@$domain';
  }

  /// Initialize audit log from disk.
  Future<void> _initializeAuditLog() async {
    try {
      final auditFile = File('$storagePath/audit_log.json');
      if (!await auditFile.exists()) return;

      final content = await auditFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      final entries = data['entries'] as List<dynamic>;
      for (final entryJson in entries) {
        final entry = AuditEntry.fromJson(entryJson);
        _auditLog.add(entry);
      }

      // Apply retention policies
      await _applyRetentionPolicies();

      logger.info('Loaded ${_auditLog.length} audit entries from disk');
    } catch (e) {
      logger.warning('Failed to load audit log: $e');
    }
  }

  /// Persist audit entry to disk.
  Future<void> _persistAuditEntry(AuditEntry entry) async {
    try {
      final auditFile = File('$storagePath/audit_log.json');
      await auditFile.parent.create(recursive: true);

      final existingEntries = <AuditEntry>[];
      if (await auditFile.exists()) {
        final content = await auditFile.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        final entries = data['entries'] as List<dynamic>;
        existingEntries.addAll(entries.map((e) => AuditEntry.fromJson(e)));
      }

      existingEntries.add(entry);

      // Apply retention policies
      final now = DateTime.now();
      final policy = privacySettings.getPolicy('audit_logs');
      if (policy != null) {
        existingEntries.removeWhere((e) => policy.isExpired(e.timestamp));
      }

      final data = {
        'version': '1.0',
        'entries': existingEntries.map((e) => e.toJson()).toList(),
      };

      await auditFile.writeAsString(json.encode(data));
    } catch (e) {
      logger.warning('Failed to persist audit entry: $e');
    }
  }

  /// Apply retention policies to cleanup old data.
  Future<void> _applyRetentionPolicies() async {
    for (final policy in privacySettings.retentionPolicies) {
      await _cleanupDataType(policy);
    }
  }

  /// Cleanup data for a specific retention policy.
  Future<int> _cleanupDataType(RetentionPolicy policy) async {
    var deletedCount = 0;

    switch (policy.deletionMethod) {
      case 'delete':
        // Remove entries completely
        _auditLog.removeWhere((entry) {
          if (policy.isExpired(entry.timestamp)) {
            deletedCount++;
            return true;
          }
          return false;
        });
        break;

      case 'anonymize':
        // Remove sensitive data but keep structure
        for (final entry in _auditLog) {
          if (policy.isExpired(entry.timestamp)) {
            // Anonymize the entry
            deletedCount++;
          }
        }
        break;

      case 'archive':
        // Move to archive (not implemented yet)
        logger.debug('Archive deletion method not yet implemented for ${policy.dataType}');
        break;
    }

    return deletedCount;
  }

  /// Start automatic retention cleanup.
  void _startRetentionCleanup() {
    // Run cleanup daily
    Future.delayed(const Duration(hours: 24), () async {
      await performRetentionCleanup();
      _startRetentionCleanup(); // Schedule next cleanup
    });
  }

  /// Get audit statistics.
  Future<Map<String, dynamic>> _getAuditStats() async {
    final actions = <String, int>{};
    final users = <String, int>{};
    final resources = <String, int>{};

    for (final entry in _auditLog) {
      actions[entry.action] = (actions[entry.action] ?? 0) + 1;
      users[entry.userId] = (users[entry.userId] ?? 0) + 1;
      resources[entry.resource] = (resources[entry.resource] ?? 0) + 1;
    }

    return {
      'totalEntries': _auditLog.length,
      'actions': actions,
      'uniqueUsers': users.length,
      'uniqueResources': resources.length,
      'dateRange': {
        'oldest': _auditLog.isNotEmpty ? _auditLog.first.timestamp.toIso8601String() : null,
        'newest': _auditLog.isNotEmpty ? _auditLog.last.timestamp.toIso8601String() : null,
      },
    };
  }

  /// Get last cleanup date.
  Future<String?> _getLastCleanupDate() async {
    // This would be stored in a separate file in a real implementation
    return null;
  }
}

/// Integration utilities for compliance in translation workflows.
class ComplianceIntegration {
  /// Creates a [ComplianceIntegration] with the given manager.
  ComplianceIntegration(this.complianceManager, this.logger);

  /// Compliance manager.
  final ComplianceManager complianceManager;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Log translation event for compliance.
  Future<void> logTranslationEvent({
    required String userId,
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
    required String provider,
    double? qualityScore,
    String? filePath,
    String? ipAddress,
    String? sessionId,
  }) async {
    await complianceManager.logAuditEvent(
      action: 'translation',
      userId: userId,
      resource: filePath ?? 'unknown_file',
      details: {
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'provider': provider,
        'qualityScore': qualityScore,
        'textLength': sourceText.length,
        'hasPersonalData': _containsPersonalData(sourceText) || _containsPersonalData(translatedText),
      },
      ipAddress: ipAddress,
      sessionId: sessionId,
      confidential: _containsPersonalData(sourceText) || _containsPersonalData(translatedText),
    );
  }

  /// Log configuration change for compliance.
  Future<void> logConfigChange({
    required String userId,
    required String setting,
    required dynamic oldValue,
    required dynamic newValue,
    String? ipAddress,
    String? sessionId,
  }) async {
    await complianceManager.logAuditEvent(
      action: 'config_change',
      userId: userId,
      resource: 'configuration',
      details: {
        'setting': setting,
        'oldValue': oldValue?.toString(),
        'newValue': newValue?.toString(),
      },
      ipAddress: ipAddress,
      sessionId: sessionId,
    );
  }

  /// Log file operation for compliance.
  Future<void> logFileOperation({
    required String userId,
    required String action,
    required String filePath,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? sessionId,
  }) async {
    await complianceManager.logAuditEvent(
      action: action,
      userId: userId,
      resource: filePath,
      details: metadata ?? {},
      ipAddress: ipAddress,
      sessionId: sessionId,
      confidential: _isSensitiveFile(filePath),
    );
  }

  /// Check if text contains personal data.
  bool _containsPersonalData(String text) {
    // Simple checks for common personal data patterns
    final personalDataPatterns = [
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN
      RegExp(r'\b\d{16}\b'), // Credit card
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Email
      RegExp(r'\b\d{3}-\d{3}-\d{4}\b'), // Phone
    ];

    return personalDataPatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// Check if file path indicates sensitive content.
  bool _isSensitiveFile(String filePath) {
    final sensitivePatterns = [
      RegExp(r'passwords?\.'),
      RegExp(r'secrets?\.'),
      RegExp(r'credentials?\.'),
      RegExp(r'private\.'),
      RegExp(r'confidential\.'),
    ];

    return sensitivePatterns.any((pattern) => pattern.hasMatch(filePath.toLowerCase()));
  }
}
