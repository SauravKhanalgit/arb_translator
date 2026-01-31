import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Analytics event for tracking usage.
class AnalyticsEvent {
  /// Creates an [AnalyticsEvent] with the given parameters.
  const AnalyticsEvent({
    required this.timestamp,
    required this.eventType,
    required this.userId,
    required this.sessionId,
    required this.properties,
    this.metadata,
  });

  /// Timestamp of the event.
  final DateTime timestamp;

  /// Type of event (translation, error, config_change, etc.).
  final String eventType;

  /// User identifier.
  final String userId;

  /// Session identifier.
  final String sessionId;

  /// Event properties.
  final Map<String, dynamic> properties;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'userId': userId,
        'sessionId': sessionId,
        'properties': properties,
        'metadata': metadata,
      };

  /// Create from JSON.
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => AnalyticsEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: json['eventType'] as String,
        userId: json['userId'] as String,
        sessionId: json['sessionId'] as String,
        properties: json['properties'] as Map<String, dynamic>,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// Translation metrics for performance tracking.
class TranslationMetrics {
  /// Creates [TranslationMetrics] with the given parameters.
  const TranslationMetrics({
    required this.totalTranslations,
    required this.successfulTranslations,
    required this.failedTranslations,
    required this.averageQualityScore,
    required this.averageProcessingTime,
    required this.providerUsage,
    required this.languagePairs,
    required this.cacheHitRate,
    required this.errorRate,
  });

  /// Total number of translations attempted.
  final int totalTranslations;

  /// Number of successful translations.
  final int successfulTranslations;

  /// Number of failed translations.
  final int failedTranslations;

  /// Average quality score (0.0 to 1.0).
  final double averageQualityScore;

  /// Average processing time in milliseconds.
  final double averageProcessingTime;

  /// Usage statistics by provider.
  final Map<String, int> providerUsage;

  /// Usage statistics by language pair.
  final Map<String, int> languagePairs;

  /// Cache hit rate (0.0 to 1.0).
  final double cacheHitRate;

  /// Error rate (0.0 to 1.0).
  final double errorRate;

  /// Success rate (0.0 to 1.0).
  double get successRate =>
      totalTranslations > 0 ? successfulTranslations / totalTranslations : 0.0;

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'totalTranslations': totalTranslations,
        'successfulTranslations': successfulTranslations,
        'failedTranslations': failedTranslations,
        'averageQualityScore': averageQualityScore,
        'averageProcessingTime': averageProcessingTime,
        'providerUsage': providerUsage,
        'languagePairs': languagePairs,
        'cacheHitRate': cacheHitRate,
        'errorRate': errorRate,
        'successRate': successRate,
      };
}

/// User engagement metrics.
class UserEngagementMetrics {
  /// Creates [UserEngagementMetrics] with the given parameters.
  const UserEngagementMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.averageSessionDuration,
    required this.mostUsedFeatures,
    required this.userRetentionRate,
    required this.featureAdoptionRate,
  });

  /// Total number of users.
  final int totalUsers;

  /// Number of active users (last 30 days).
  final int activeUsers;

  /// Average session duration in minutes.
  final double averageSessionDuration;

  /// Most used features by frequency.
  final Map<String, int> mostUsedFeatures;

  /// User retention rate (0.0 to 1.0).
  final double userRetentionRate;

  /// Feature adoption rate by percentage of users.
  final Map<String, double> featureAdoptionRate;
}

/// Comprehensive analytics and reporting system.
class AnalyticsManager {
  /// Creates an [AnalyticsManager] with the given configuration.
  AnalyticsManager({
    required this.storagePath,
    required this.logger,
    this.enableAnalytics = true,
    this.maxStoredEvents = 50000,
  }) {
    if (enableAnalytics) {
      _loadEventsFromDisk();
    }
  }

  /// Path for storing analytics data.
  final String storagePath;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Whether analytics collection is enabled.
  final bool enableAnalytics;

  /// Maximum number of events to store.
  final int maxStoredEvents;

  /// Stored analytics events.
  final List<AnalyticsEvent> _events = [];

  /// Translation metrics cache.
  TranslationMetrics? _cachedMetrics;

  /// Last metrics calculation time.
  DateTime? _lastMetricsCalculation;

  /// Track a user action.
  Future<void> trackEvent({
    required String eventType,
    required String userId,
    required String sessionId,
    required Map<String, dynamic> properties,
    Map<String, dynamic>? metadata,
  }) async {
    if (!enableAnalytics) return;

    final event = AnalyticsEvent(
      timestamp: DateTime.now(),
      eventType: eventType,
      userId: userId,
      sessionId: sessionId,
      properties: properties,
      metadata: metadata,
    );

    _events.add(event);

    // Maintain size limits
    if (_events.length > maxStoredEvents) {
      _events.removeRange(0, _events.length - maxStoredEvents);
    }

    // Invalidate cached metrics
    _cachedMetrics = null;

    await _persistEvent(event);
  }

  /// Track translation completion.
  Future<void> trackTranslation({
    required String userId,
    required String sessionId,
    required String sourceLang,
    required String targetLang,
    required String provider,
    required bool success,
    double? qualityScore,
    int? processingTimeMs,
    bool? cacheHit,
    String? errorType,
  }) async {
    await trackEvent(
      eventType: 'translation',
      userId: userId,
      sessionId: sessionId,
      properties: {
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'provider': provider,
        'success': success,
        'qualityScore': qualityScore,
        'processingTimeMs': processingTimeMs,
        'cacheHit': cacheHit,
        'errorType': errorType,
      },
    );
  }

  /// Track error occurrence.
  Future<void> trackError({
    required String userId,
    required String sessionId,
    required String errorType,
    required String errorMessage,
    String? component,
    Map<String, dynamic>? context,
  }) async {
    await trackEvent(
      eventType: 'error',
      userId: userId,
      sessionId: sessionId,
      properties: {
        'errorType': errorType,
        'errorMessage': errorMessage,
        'component': component,
      },
      metadata: context,
    );
  }

  /// Track feature usage.
  Future<void> trackFeatureUsage({
    required String userId,
    required String sessionId,
    required String feature,
    Map<String, dynamic>? parameters,
  }) async {
    await trackEvent(
      eventType: 'feature_usage',
      userId: userId,
      sessionId: sessionId,
      properties: {
        'feature': feature,
        ...?parameters,
      },
    );
  }

  /// Get translation metrics.
  Future<TranslationMetrics> getTranslationMetrics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // Return cached metrics if recent
    if (_cachedMetrics != null &&
        _lastMetricsCalculation != null &&
        DateTime.now().difference(_lastMetricsCalculation!).inMinutes < 5) {
      return _cachedMetrics!;
    }

    final relevantEvents = _filterEventsByDate(_events, fromDate, toDate)
        .where((event) => event.eventType == 'translation')
        .toList();

    if (relevantEvents.isEmpty) {
      return const TranslationMetrics(
        totalTranslations: 0,
        successfulTranslations: 0,
        failedTranslations: 0,
        averageQualityScore: 0.0,
        averageProcessingTime: 0.0,
        providerUsage: {},
        languagePairs: {},
        cacheHitRate: 0.0,
        errorRate: 0.0,
      );
    }

    final totalTranslations = relevantEvents.length;
    final successfulEvents =
        relevantEvents.where((e) => e.properties['success'] == true);
    final successfulTranslations = successfulEvents.length;
    final failedTranslations = totalTranslations - successfulTranslations;

    // Calculate average quality score
    final qualityScores = successfulEvents
        .map((e) => e.properties['qualityScore'] as double?)
        .where((score) => score != null)
        .cast<double>();
    final averageQualityScore = qualityScores.isEmpty
        ? 0.0
        : qualityScores.reduce((a, b) => a + b) / qualityScores.length;

    // Calculate average processing time
    final processingTimes = relevantEvents
        .map((e) => e.properties['processingTimeMs'] as int?)
        .where((time) => time != null)
        .cast<int>();
    final averageProcessingTime = processingTimes.isEmpty
        ? 0.0
        : processingTimes.reduce((a, b) => a + b) / processingTimes.length;

    // Provider usage statistics
    final providerUsage = <String, int>{};
    for (final event in relevantEvents) {
      final provider = event.properties['provider'] as String? ?? 'unknown';
      providerUsage[provider] = (providerUsage[provider] ?? 0) + 1;
    }

    // Language pair statistics
    final languagePairs = <String, int>{};
    for (final event in relevantEvents) {
      final sourceLang = event.properties['sourceLang'] as String? ?? 'unknown';
      final targetLang = event.properties['targetLang'] as String? ?? 'unknown';
      final pair = '$sourceLang->$targetLang';
      languagePairs[pair] = (languagePairs[pair] ?? 0) + 1;
    }

    // Cache hit rate
    final cacheHits =
        relevantEvents.where((e) => e.properties['cacheHit'] == true).length;
    final cacheHitRate =
        totalTranslations > 0 ? cacheHits / totalTranslations : 0.0;

    // Error rate
    final errors =
        relevantEvents.where((e) => e.properties['errorType'] != null).length;
    final errorRate = totalTranslations > 0 ? errors / totalTranslations : 0.0;

    _cachedMetrics = TranslationMetrics(
      totalTranslations: totalTranslations,
      successfulTranslations: successfulTranslations,
      failedTranslations: failedTranslations,
      averageQualityScore: averageQualityScore,
      averageProcessingTime: averageProcessingTime,
      providerUsage: providerUsage,
      languagePairs: languagePairs,
      cacheHitRate: cacheHitRate,
      errorRate: errorRate,
    );

    _lastMetricsCalculation = DateTime.now();
    return _cachedMetrics!;
  }

  /// Get user engagement metrics.
  Future<UserEngagementMetrics> getUserEngagementMetrics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final relevantEvents = _filterEventsByDate(_events, fromDate, toDate);

    // Get unique users
    final uniqueUsers = relevantEvents.map((e) => e.userId).toSet();
    final totalUsers = uniqueUsers.length;

    // Active users (events in last 30 days)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final activeUsers = relevantEvents
        .where((e) => e.timestamp.isAfter(thirtyDaysAgo))
        .map((e) => e.userId)
        .toSet()
        .length;

    // Average session duration (simplified)
    final sessionDurations = <String, List<DateTime>>{};
    for (final event in relevantEvents) {
      sessionDurations
          .putIfAbsent(event.sessionId, () => [])
          .add(event.timestamp);
    }

    var totalSessionTime = 0.0;
    var sessionCount = 0;
    for (final timestamps in sessionDurations.values) {
      if (timestamps.length > 1) {
        timestamps.sort();
        final duration = timestamps.last.difference(timestamps.first).inMinutes;
        totalSessionTime += duration;
        sessionCount++;
      }
    }

    final averageSessionDuration =
        sessionCount > 0 ? totalSessionTime / sessionCount : 0.0;

    // Most used features
    final featureUsage = <String, int>{};
    final featureEvents =
        relevantEvents.where((e) => e.eventType == 'feature_usage');
    for (final event in featureEvents) {
      final feature = event.properties['feature'] as String? ?? 'unknown';
      featureUsage[feature] = (featureUsage[feature] ?? 0) + 1;
    }

    // Sort by usage
    final mostUsedFeatures = Map.fromEntries(featureUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10));

    // User retention rate (simplified - users with events in both halves of period)
    final retentionRate = _calculateRetentionRate(relevantEvents);

    // Feature adoption rate
    final featureAdoption = <String, double>{};
    for (final feature in featureUsage.keys) {
      final usersUsingFeature = relevantEvents
          .where((e) => e.properties['feature'] == feature)
          .map((e) => e.userId)
          .toSet()
          .length;
      featureAdoption[feature] =
          totalUsers > 0 ? usersUsingFeature / totalUsers : 0.0;
    }

    return UserEngagementMetrics(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      averageSessionDuration: averageSessionDuration,
      mostUsedFeatures: mostUsedFeatures,
      userRetentionRate: retentionRate,
      featureAdoptionRate: featureAdoption,
    );
  }

  /// Generate comprehensive analytics report.
  Future<String> generateAnalyticsReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final translationMetrics =
        await getTranslationMetrics(fromDate: fromDate, toDate: toDate);
    final engagementMetrics =
        await getUserEngagementMetrics(fromDate: fromDate, toDate: toDate);

    final report = {
      'generatedAt': DateTime.now().toIso8601String(),
      'dateRange': {
        'from': fromDate?.toIso8601String(),
        'to': toDate?.toIso8601String(),
      },
      'summary': {
        'totalEvents': _events.length,
        'dateRange': {
          'oldest': _events.isNotEmpty
              ? _events.first.timestamp.toIso8601String()
              : null,
          'newest': _events.isNotEmpty
              ? _events.last.timestamp.toIso8601String()
              : null,
        },
      },
      'translationMetrics': translationMetrics.toJson(),
      'userEngagement': {
        'totalUsers': engagementMetrics.totalUsers,
        'activeUsers': engagementMetrics.activeUsers,
        'averageSessionDuration': engagementMetrics.averageSessionDuration,
        'userRetentionRate': engagementMetrics.userRetentionRate,
        'mostUsedFeatures': engagementMetrics.mostUsedFeatures,
        'featureAdoptionRate': engagementMetrics.featureAdoptionRate,
      },
      'performance': {
        'successRate': translationMetrics.successRate,
        'averageQualityScore': translationMetrics.averageQualityScore,
        'averageProcessingTime': translationMetrics.averageProcessingTime,
        'cacheHitRate': translationMetrics.cacheHitRate,
        'errorRate': translationMetrics.errorRate,
      },
      'usage': {
        'providerUsage': translationMetrics.providerUsage,
        'languagePairs': translationMetrics.languagePairs,
      },
    };

    return json.encode(report);
  }

  /// Export analytics data.
  Future<String> exportAnalyticsData({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? eventTypes,
  }) async {
    final relevantEvents = _filterEventsByDate(_events, fromDate, toDate);

    final filteredEvents = eventTypes != null
        ? relevantEvents.where((e) => eventTypes.contains(e.eventType)).toList()
        : relevantEvents;

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEvents': filteredEvents.length,
      'filters': {
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
        'eventTypes': eventTypes,
      },
      'events': filteredEvents.map((e) => e.toJson()).toList(),
    };

    return json.encode(exportData);
  }

  /// Clear all analytics data.
  void clearAnalytics() {
    _events.clear();
    _cachedMetrics = null;
    _lastMetricsCalculation = null;
    logger.info('Analytics data cleared');
  }

  /// Filter events by date range.
  List<AnalyticsEvent> _filterEventsByDate(
    List<AnalyticsEvent> events,
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    return events.where((event) {
      if (fromDate != null && event.timestamp.isBefore(fromDate)) return false;
      if (toDate != null && event.timestamp.isAfter(toDate)) return false;
      return true;
    }).toList();
  }

  /// Calculate user retention rate.
  double _calculateRetentionRate(List<AnalyticsEvent> events) {
    if (events.isEmpty) return 0.0;

    final midPoint = events.length ~/ 2;
    final firstHalf = events.sublist(0, midPoint);
    final secondHalf = events.sublist(midPoint);

    final firstHalfUsers = firstHalf.map((e) => e.userId).toSet();
    final secondHalfUsers = secondHalf.map((e) => e.userId).toSet();

    final retainedUsers = firstHalfUsers.intersection(secondHalfUsers).length;
    return firstHalfUsers.isNotEmpty
        ? retainedUsers / firstHalfUsers.length
        : 0.0;
  }

  /// Load events from disk.
  Future<void> _loadEventsFromDisk() async {
    try {
      final analyticsFile = File('$storagePath/analytics.json');
      if (!await analyticsFile.exists()) return;

      final content = await analyticsFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      final events = data['events'] as List<dynamic>;
      for (final eventJson in events) {
        final event =
            AnalyticsEvent.fromJson(eventJson as Map<String, dynamic>);
        _events.add(event);
      }

      logger.info('Loaded ${_events.length} analytics events from disk');
    } catch (e) {
      logger.warning('Failed to load analytics data: $e');
    }
  }

  /// Persist event to disk.
  Future<void> _persistEvent(AnalyticsEvent event) async {
    try {
      final analyticsFile = File('$storagePath/analytics.json');
      await analyticsFile.parent.create(recursive: true);

      final existingEvents = <AnalyticsEvent>[];
      if (await analyticsFile.exists()) {
        final content = await analyticsFile.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>;
        existingEvents.addAll(events
            .map((e) => AnalyticsEvent.fromJson(e as Map<String, dynamic>)));
      }

      existingEvents.add(event);

      // Maintain size limits
      if (existingEvents.length > maxStoredEvents) {
        existingEvents.removeRange(0, existingEvents.length - maxStoredEvents);
      }

      final data = {
        'version': '1.0',
        'events': existingEvents.map((e) => e.toJson()).toList(),
      };

      await analyticsFile.writeAsString(json.encode(data));
    } catch (e) {
      logger.warning('Failed to persist analytics event: $e');
    }
  }
}

/// Integration utilities for analytics in translation workflows.
class AnalyticsIntegration {
  /// Creates an [AnalyticsIntegration] with the given manager.
  AnalyticsIntegration(this.analyticsManager, this.logger);

  /// Analytics manager.
  final AnalyticsManager analyticsManager;

  /// Logger for operations.
  final TranslatorLogger logger;

  /// Track translation workflow.
  Future<void> trackTranslationWorkflow({
    required String userId,
    required String sessionId,
    required String operation,
    required Map<String, dynamic> metrics,
  }) async {
    await analyticsManager.trackEvent(
      eventType: 'workflow',
      userId: userId,
      sessionId: sessionId,
      properties: {
        'operation': operation,
        ...metrics,
      },
    );
  }

  /// Generate performance dashboard data.
  Future<Map<String, dynamic>> generateDashboardData() async {
    final translationMetrics = await analyticsManager.getTranslationMetrics();
    final engagementMetrics = await analyticsManager.getUserEngagementMetrics();

    return {
      'summary': {
        'totalTranslations': translationMetrics.totalTranslations,
        'successRate': translationMetrics.successRate,
        'averageQuality': translationMetrics.averageQualityScore,
        'activeUsers': engagementMetrics.activeUsers,
      },
      'performance': {
        'processingTime': translationMetrics.averageProcessingTime,
        'cacheHitRate': translationMetrics.cacheHitRate,
        'errorRate': translationMetrics.errorRate,
      },
      'usage': {
        'topProviders': translationMetrics.providerUsage.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5),
        'topLanguagePairs': translationMetrics.languagePairs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5),
        'topFeatures': engagementMetrics.mostUsedFeatures.entries.toList()
          ..take(5),
      },
      'trends': {
        'userRetention': engagementMetrics.userRetentionRate,
        'featureAdoption': engagementMetrics.featureAdoptionRate,
      },
    };
  }

  /// Export analytics dashboard as HTML.
  Future<String> exportDashboardHtml() async {
    final dashboardData = await generateDashboardData();

    final html = '''
<!DOCTYPE html>
<html>
<head>
    <title>ARB Translator Analytics Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .metric h3 { margin: 0 0 10px 0; color: #333; }
        .metric .value { font-size: 24px; font-weight: bold; color: #007acc; }
        .chart { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>ARB Translator Analytics Dashboard</h1>
    <p>Generated on ${DateTime.now().toString()}</p>

    <div class="metric">
        <h3>Total Translations</h3>
        <div class="value">${dashboardData['summary']['totalTranslations']}</div>
    </div>

    <div class="metric">
        <h3>Success Rate</h3>
        <div class="value">${(dashboardData['summary']['successRate'] * 100).toStringAsFixed(1)}%</div>
    </div>

    <div class="metric">
        <h3>Average Quality Score</h3>
        <div class="value">${dashboardData['summary']['averageQuality'].toStringAsFixed(2)}</div>
    </div>

    <div class="metric">
        <h3>Active Users</h3>
        <div class="value">${dashboardData['summary']['activeUsers']}</div>
    </div>

    <h2>Top Providers</h2>
    <table>
        <tr><th>Provider</th><th>Usage Count</th></tr>
        ${dashboardData['usage']['topProviders'].map((dynamic entry) => '<tr><td>${entry['key']}</td><td>${entry['value']}</td></tr>').join()}
    </table>

    <h2>Top Language Pairs</h2>
    <table>
        <tr><th>Language Pair</th><th>Usage Count</th></tr>
        ${dashboardData['usage']['topLanguagePairs'].map((dynamic entry) => '<tr><td>${entry['key']}</td><td>${entry['value']}</td></tr>').join()}
    </table>
</body>
</html>
''';

    return html;
  }
}
