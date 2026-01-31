import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Real-time collaboration manager for team translation workflows.
/// Provides conflict resolution, review workflows, and live synchronization.
class CollaborationManager {
  /// Creates a collaboration manager.
  CollaborationManager({
    required this.config,
    this.enableWebSocket = true,
    this.conflictResolutionStrategy = ConflictResolutionStrategy.lastWriterWins,
  }) {
    _logger = TranslatorLogger()..initialize(config.logLevel);
    _projects = <String, _CollaborativeProject>{};
    _activeUsers = <String, _CollaborativeUser>{};
  }

  /// Configuration for the translator.
  final TranslatorConfig config;

  /// Whether to enable WebSocket support for real-time updates.
  final bool enableWebSocket;

  /// Strategy for resolving conflicts.
  final ConflictResolutionStrategy conflictResolutionStrategy;

  late final TranslatorLogger _logger;
  late final Map<String, _CollaborativeProject> _projects;
  late final Map<String, _CollaborativeUser> _activeUsers;

  HttpServer? _server;
  final Map<String, WebSocket> _connectedClients = {};

  /// Get all active projects.
  Map<String, Map<String, dynamic>> get activeProjects {
    return _projects.map((key, project) => MapEntry(key, project.toJson()));
  }

  /// Get all active users.
  Map<String, Map<String, dynamic>> get activeUsers {
    return _activeUsers.map((key, user) => MapEntry(key, user.toJson()));
  }

  /// Initialize the collaboration manager.
  Future<void> initialize() async {
    _logger.info('🤝 Initializing collaboration manager...');
    _logger.info('🌐 WebSocket enabled: $enableWebSocket');
    _logger.info('⚖️  Conflict resolution: $conflictResolutionStrategy');

    if (enableWebSocket) {
      await _startWebSocketServer();
    }

    // Start cleanup timers
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupInactiveUsers();
      _cleanupStaleLocks();
    });

    _logger.info('✅ Collaboration manager initialized');
  }

  /// Create a new collaborative project.
  Future<String> createProject({
    required String name,
    required String sourceLanguage,
    required List<String> targetLanguages,
    required String creatorId,
    required String creatorName,
    Map<String, dynamic>? settings,
  }) async {
    final projectId = 'proj-${DateTime.now().millisecondsSinceEpoch}';
    final project = _CollaborativeProject(
      id: projectId,
      name: name,
      sourceLanguage: sourceLanguage,
      targetLanguages: targetLanguages,
      creatorId: creatorId,
      creatorName: creatorName,
      settings: settings ?? {},
      createdAt: DateTime.now(),
      manager: this,
    );

    _projects[projectId] = project;

    _logger.info('📁 Created collaborative project: $name ($projectId)');
    _broadcastUpdate('project_created', {'project': project.toJson()});

    return projectId;
  }

  /// Join a collaborative project.
  Future<bool> joinProject({
    required String projectId,
    required String userId,
    required String userName,
    required List<String> permissions,
  }) async {
    final project = _projects[projectId];
    if (project == null) {
      _logger.warning('Project not found: $projectId');
      return false;
    }

    final user = _CollaborativeUser(
      id: userId,
      name: userName,
      projectId: projectId,
      permissions: permissions,
      joinedAt: DateTime.now(),
      lastActivity: DateTime.now(),
    );

    _activeUsers[userId] = user;
    project.addUser(user);

    _logger.info('👤 User $userName joined project $projectId');
    _broadcastToProject(projectId, 'user_joined', {'user': user.toJson()});

    return true;
  }

  /// Leave a collaborative project.
  Future<void> leaveProject(String userId) async {
    final user = _activeUsers[userId];
    if (user == null) return;

    final project = _projects[user.projectId];
    if (project != null) {
      project.removeUser(userId);
      _broadcastToProject(user.projectId, 'user_left', {'userId': userId});
    }

    _activeUsers.remove(userId);
    _logger.info('👤 User ${user.name} left project ${user.projectId}');
  }

  /// Update a translation in a collaborative project.
  Future<ConflictResolutionResult> updateTranslation({
    required String projectId,
    required String userId,
    required String language,
    required String key,
    required String newValue,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final project = _projects[projectId];
    if (project == null) {
      return ConflictResolutionResult.failure('Project not found');
    }

    final user = _activeUsers[userId];
    if (user == null) {
      return ConflictResolutionResult.failure('User not authenticated');
    }

    // Check permissions
    if (!user.permissions.contains('write')) {
      return ConflictResolutionResult.failure('Insufficient permissions');
    }

    // Check for conflicts
    final existingTranslation = project.getTranslation(language, key);
    if (existingTranslation != null) {
      final conflict = _detectConflict(existingTranslation, newValue, userId);
      if (conflict.isConflicting) {
        final resolution = await _resolveConflict(conflict, userId);
        if (!resolution.accepted) {
          return ConflictResolutionResult.conflict(conflict, resolution);
        }
      }
    }

    // Apply the update
    final update = _TranslationUpdate(
      id: 'update-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      userId: userId,
      language: language,
      key: key,
      oldValue: existingTranslation?.value,
      newValue: newValue,
      description: description,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    project.applyUpdate(update);
    user.updateActivity();

    _logger.info('✏️  Translation updated: $language.$key by ${user.name}');
    _broadcastToProject(projectId, 'translation_updated', update.toJson());

    return ConflictResolutionResult.success(update);
  }

  /// Request a review for a translation.
  Future<void> requestReview({
    required String projectId,
    required String userId,
    required String language,
    required String key,
    String? comment,
  }) async {
    final project = _projects[projectId];
    if (project == null) return;

    final review = _TranslationReview(
      id: 'review-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      requesterId: userId,
      language: language,
      key: key,
      comment: comment,
      status: ReviewStatus.pending,
      createdAt: DateTime.now(),
    );

    project.addReview(review);

    _logger.info('🔍 Review requested: $language.$key');
    _broadcastToProject(projectId, 'review_requested', review.toJson());
  }

  /// Submit a review decision.
  Future<void> submitReviewDecision({
    required String reviewId,
    required String reviewerId,
    required ReviewDecision decision,
    String? comment,
  }) async {
    // Find the review across all projects
    _TranslationReview? review;
    for (final project in _projects.values) {
      review = project.getReview(reviewId);
      if (review != null) break;
    }

    if (review == null) {
      _logger.warning('Review not found: $reviewId');
      return;
    }

    final decisionObj = _ReviewDecision(
      reviewerId: reviewerId,
      decision: decision,
      comment: comment,
      timestamp: DateTime.now(),
    );

    review.decisions.add(decisionObj);

    // Auto-resolve if all reviewers approved or if there's a rejection
    if (decision == ReviewDecision.reject) {
      review.status = ReviewStatus.rejected;
    } else if (review.decisions
        .every((d) => d.decision == ReviewDecision.approve)) {
      review.status = ReviewStatus.approved;
    }

    _logger.info('✅ Review decision: $decision for review $reviewId');
    _broadcastToProject(review.projectId, 'review_decision', {
      'reviewId': reviewId,
      'decision': decisionObj.toJson(),
      'status': review.status.name,
    });
  }

  /// Lock a translation key for editing.
  Future<bool> lockTranslation({
    required String projectId,
    required String userId,
    required String language,
    required String key,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final project = _projects[projectId];
    if (project == null) return false;

    final user = _activeUsers[userId];
    if (user == null) return false;

    final lock = _TranslationLock(
      id: 'lock-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      userId: userId,
      language: language,
      key: key,
      acquiredAt: DateTime.now(),
      expiresAt: DateTime.now().add(timeout),
    );

    final success = project.addLock(lock);
    if (success) {
      _logger.info('🔒 Translation locked: $language.$key by ${user.name}');
      _broadcastToProject(projectId, 'translation_locked', lock.toJson());
    }

    return success;
  }

  /// Unlock a translation key.
  Future<void> unlockTranslation({
    required String projectId,
    required String userId,
    required String language,
    required String key,
  }) async {
    final project = _projects[projectId];
    if (project == null) return;

    project.removeLock(userId, language, key);
    _logger.info('🔓 Translation unlocked: $language.$key');
    _broadcastToProject(projectId, 'translation_unlocked', {
      'userId': userId,
      'language': language,
      'key': key,
    });
  }

  /// Get project statistics.
  Map<String, dynamic> getProjectStatistics(String projectId) {
    final project = _projects[projectId];
    if (project == null) {
      return {'error': 'Project not found'};
    }

    return project.getStatistics();
  }

  /// Export project data.
  Future<Map<String, dynamic>> exportProject(String projectId) async {
    final project = _projects[projectId];
    if (project == null) {
      return {'error': 'Project not found'};
    }

    return project.export();
  }

  /// Shutdown the collaboration manager.
  Future<void> shutdown() async {
    _logger.info('🛑 Shutting down collaboration manager...');

    // Close all WebSocket connections
    for (final client in _connectedClients.values) {
      await client.close();
    }
    _connectedClients.clear();

    // Stop the server
    await _server?.close();

    // Clear all data
    _projects.clear();
    _activeUsers.clear();

    _logger.info('✅ Collaboration manager shutdown complete');
  }

  /// Start WebSocket server for real-time updates.
  Future<void> _startWebSocketServer() async {
    try {
      _server = await HttpServer.bind('localhost', 8081);
      _logger.info('🌐 WebSocket server started on ws://localhost:8081');

      await for (final request in _server!) {
        if (request.uri.path == '/ws') {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleWebSocketConnection(socket);
        } else {
          request.response
            ..statusCode = 404
            ..write('Not found')
            ..close();
        }
      }
    } catch (e) {
      _logger.error('Failed to start WebSocket server', e);
    }
  }

  /// Handle WebSocket connection.
  void _handleWebSocketConnection(WebSocket socket) {
    final clientId = 'client-${DateTime.now().millisecondsSinceEpoch}';
    _connectedClients[clientId] = socket;

    socket.listen(
      (message) {
        try {
          final data = json.decode(message as String) as Map<String, dynamic>;
          _handleWebSocketMessage(clientId, socket, data);
        } catch (e) {
          _logger.error('WebSocket message error', e);
        }
      },
      onDone: () {
        _connectedClients.remove(clientId);
      },
      onError: (dynamic error) {
        _logger.error('WebSocket error', error);
        _connectedClients.remove(clientId);
      },
    );

    _logger.debug('🔌 WebSocket client connected: $clientId');
  }

  /// Handle WebSocket message.
  void _handleWebSocketMessage(
      String clientId, WebSocket socket, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final payload = data['payload'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'join_project':
        joinProject(
          projectId: payload['projectId'] as String,
          userId: payload['userId'] as String,
          userName: payload['userName'] as String,
          permissions:
              List<String>.from(payload['permissions'] as Iterable? ?? []),
        );
        break;

      case 'leave_project':
        leaveProject(payload['userId'] as String);
        break;

      case 'update_translation':
        updateTranslation(
          projectId: payload['projectId'] as String,
          userId: payload['userId'] as String,
          language: payload['language'] as String,
          key: payload['key'] as String,
          newValue: payload['value'] as String,
          description: payload['description'] as String?,
        );
        break;

      case 'request_review':
        requestReview(
          projectId: payload['projectId'] as String,
          userId: payload['userId'] as String,
          language: payload['language'] as String,
          key: payload['key'] as String,
          comment: payload['comment'] as String?,
        );
        break;

      case 'ping':
        socket.add(json.encode(
            {'type': 'pong', 'timestamp': DateTime.now().toIso8601String()}));
        break;
    }
  }

  /// Broadcast message to all connected clients.
  void _broadcastUpdate(String type, Map<String, dynamic> payload) {
    final message = json.encode({
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });

    for (final socket in _connectedClients.values) {
      socket.add(message);
    }
  }

  /// Broadcast message to clients in a specific project.
  void _broadcastToProject(
      String projectId, String type, Map<String, dynamic> payload) {
    final message = json.encode({
      'type': type,
      'payload': payload,
      'projectId': projectId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // In a real implementation, you'd track which clients are in which projects
    // For now, broadcast to all clients
    for (final socket in _connectedClients.values) {
      socket.add(message);
    }
  }

  /// Detect conflicts between translations.
  _TranslationConflict _detectConflict(
      _TranslationEntry existing, String newValue, String userId) {
    return _TranslationConflict(
      key: existing.key,
      language: existing.language,
      existingValue: existing.value,
      newValue: newValue,
      existingUserId: existing.lastModifiedBy,
      newUserId: userId,
      existingTimestamp: existing.lastModifiedAt,
      newTimestamp: DateTime.now(),
    );
  }

  /// Resolve conflicts based on strategy.
  Future<_ConflictResolution> _resolveConflict(
      _TranslationConflict conflict, String userId) async {
    switch (conflictResolutionStrategy) {
      case ConflictResolutionStrategy.lastWriterWins:
        return _ConflictResolution(
          accepted: conflict.newTimestamp.isAfter(conflict.existingTimestamp),
          reason: 'Last writer wins',
        );

      case ConflictResolutionStrategy.manualResolution:
        // In a real implementation, this would prompt the user
        return _ConflictResolution(
          accepted: false,
          reason: 'Manual resolution required',
        );

      case ConflictResolutionStrategy.versionControl:
        // Check if the change is substantial
        final similarity =
            _calculateSimilarity(conflict.existingValue, conflict.newValue);
        return _ConflictResolution(
          accepted: similarity < 0.8, // Accept if changes are significant
          reason:
              'Version control: similarity ${similarity.toStringAsFixed(2)}',
        );

      case ConflictResolutionStrategy.userPriority:
        // Accept if the new user has higher priority
        final newUserPriority = _getUserPriority(userId);
        final existingUserPriority = _getUserPriority(conflict.existingUserId);
        return _ConflictResolution(
          accepted: newUserPriority >= existingUserPriority,
          reason: 'User priority: $newUserPriority vs $existingUserPriority',
        );
    }
  }

  /// Calculate similarity between two strings (simple implementation).
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    if (longer.contains(shorter)) return shorter.length / longer.length;

    // Simple Levenshtein distance approximation
    final distance = _levenshteinDistance(a, b);
    return 1.0 - (distance / longer.length);
  }

  /// Calculate Levenshtein distance.
  int _levenshteinDistance(String a, String b) {
    final matrix =
        List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Get user priority (simple implementation).
  int _getUserPriority(String userId) {
    final user = _activeUsers[userId];
    if (user == null) return 0;

    // Higher priority for users with more permissions or longer activity
    var priority = user.permissions.length;
    final hoursActive = DateTime.now().difference(user.joinedAt).inHours;
    priority += hoursActive ~/ 24; // 1 point per day active

    return priority;
  }

  /// Clean up inactive users.
  void _cleanupInactiveUsers() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final inactiveUsers = _activeUsers.entries
        .where((entry) => entry.value.lastActivity.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList();

    for (final userId in inactiveUsers) {
      leaveProject(userId);
    }
  }

  /// Clean up stale locks.
  void _cleanupStaleLocks() {
    final now = DateTime.now();
    for (final project in _projects.values) {
      project.cleanupStaleLocks(now);
    }
  }
}

/// Conflict resolution strategies.
enum ConflictResolutionStrategy {
  lastWriterWins,
  manualResolution,
  versionControl,
  userPriority,
}

/// Review statuses.
enum ReviewStatus { pending, approved, rejected }

/// Review decisions.
enum ReviewDecision { approve, reject, requestChanges }

/// Result of conflict resolution.
class ConflictResolutionResult {
  ConflictResolutionResult._(
      this.success, this.conflict, this.resolution, this.update, this.error);

  factory ConflictResolutionResult.success(_TranslationUpdate update) {
    return ConflictResolutionResult._(true, null, null, update, null);
  }

  factory ConflictResolutionResult.conflict(
      _TranslationConflict conflict, _ConflictResolution resolution) {
    return ConflictResolutionResult._(false, conflict, resolution, null, null);
  }

  factory ConflictResolutionResult.failure(String error) {
    return ConflictResolutionResult._(false, null, null, null, error);
  }

  final bool success;
  final _TranslationConflict? conflict;
  final _ConflictResolution? resolution;
  final _TranslationUpdate? update;
  final String? error;
}

// Internal classes for collaboration system

class _CollaborativeProject {
  _CollaborativeProject({
    required this.id,
    required this.name,
    required this.sourceLanguage,
    required this.targetLanguages,
    required this.creatorId,
    required this.creatorName,
    required this.settings,
    required this.createdAt,
    required this.manager,
  });

  final String id;
  final String name;
  final String sourceLanguage;
  final List<String> targetLanguages;
  final String creatorId;
  final String creatorName;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final CollaborationManager manager;

  final Map<String, _CollaborativeUser> _users = {};
  final Map<String, Map<String, _TranslationEntry>> _translations = {};
  final List<_TranslationUpdate> _updates = [];
  final List<_TranslationReview> _reviews = [];
  final List<_TranslationLock> _locks = [];

  void addUser(_CollaborativeUser user) {
    _users[user.id] = user;
  }

  void removeUser(String userId) {
    _users.remove(userId);
  }

  _TranslationEntry? getTranslation(String language, String key) {
    return _translations[language]?[key];
  }

  void applyUpdate(_TranslationUpdate update) {
    _translations.putIfAbsent(update.language, () => {});
    _translations[update.language]![update.key] = _TranslationEntry(
      key: update.key,
      language: update.language,
      value: update.newValue,
      description: update.description,
      lastModifiedBy: update.userId,
      lastModifiedAt: update.timestamp,
    );
    _updates.add(update);
  }

  void addReview(_TranslationReview review) {
    _reviews.add(review);
  }

  _TranslationReview? getReview(String reviewId) {
    return _reviews.cast<_TranslationReview?>().firstWhere(
          (review) => review?.id == reviewId,
          orElse: () => null,
        );
  }

  bool addLock(_TranslationLock lock) {
    // Check if already locked
    final existingLock = _locks.firstWhere(
      (l) => l.language == lock.language && l.key == lock.key,
      orElse: () => _TranslationLock.empty(),
    );

    if (existingLock.id.isNotEmpty) {
      return false; // Already locked
    }

    _locks.add(lock);
    return true;
  }

  void removeLock(String userId, String language, String key) {
    _locks.removeWhere((lock) =>
        lock.userId == userId && lock.language == language && lock.key == key);
  }

  void cleanupStaleLocks(DateTime now) {
    _locks.removeWhere((lock) => lock.expiresAt.isBefore(now));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceLanguage': sourceLanguage,
      'targetLanguages': targetLanguages,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'settings': settings,
      'createdAt': createdAt.toIso8601String(),
      'userCount': _users.length,
      'translationCount':
          _translations.values.fold(0, (sum, lang) => sum + lang.length),
      'reviewCount': _reviews.length,
      'activeLocks': _locks.length,
    };
  }

  Map<String, dynamic> getStatistics() {
    final totalTranslations =
        _translations.values.fold(0, (sum, lang) => sum + lang.length);
    final completedReviews =
        _reviews.where((r) => r.status != ReviewStatus.pending).length;

    return {
      'totalUsers': _users.length,
      'totalTranslations': totalTranslations,
      'totalUpdates': _updates.length,
      'totalReviews': _reviews.length,
      'completedReviews': completedReviews,
      'activeLocks': _locks.length,
      'completionRate':
          _reviews.isEmpty ? 0.0 : completedReviews / _reviews.length,
      'lastActivity':
          _updates.isEmpty ? null : _updates.last.timestamp.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> export() async {
    return {
      'project': toJson(),
      'users': _users.values.map((u) => u.toJson()).toList(),
      'translations': _translations.map((lang, entries) =>
          MapEntry(lang, entries.values.map((e) => e.toJson()).toList())),
      'updates': _updates.map((u) => u.toJson()).toList(),
      'reviews': _reviews.map((r) => r.toJson()).toList(),
      'locks': _locks.map((l) => l.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}

class _CollaborativeUser {
  _CollaborativeUser({
    required this.id,
    required this.name,
    required this.projectId,
    required this.permissions,
    required this.joinedAt,
    required DateTime lastActivity,
  }) : _lastActivity = lastActivity;

  final String id;
  final String name;
  final String projectId;
  final List<String> permissions;
  final DateTime joinedAt;

  DateTime _lastActivity;

  DateTime get lastActivity => _lastActivity;

  void updateActivity() {
    _lastActivity = DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectId': projectId,
      'permissions': permissions,
      'joinedAt': joinedAt.toIso8601String(),
      'lastActivity': _lastActivity.toIso8601String(),
    };
  }
}

class _TranslationEntry {
  _TranslationEntry({
    required this.key,
    required this.language,
    required this.value,
    this.description,
    required this.lastModifiedBy,
    required this.lastModifiedAt,
  });

  final String key;
  final String language;
  final String value;
  final String? description;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'language': language,
      'value': value,
      'description': description,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
    };
  }
}

class _TranslationUpdate {
  _TranslationUpdate({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.language,
    required this.key,
    this.oldValue,
    required this.newValue,
    this.description,
    this.metadata,
    required this.timestamp,
  });

  final String id;
  final String projectId;
  final String userId;
  final String language;
  final String key;
  final String? oldValue;
  final String newValue;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'language': language,
      'key': key,
      'oldValue': oldValue,
      'newValue': newValue,
      'description': description,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class _TranslationReview {
  _TranslationReview({
    required this.id,
    required this.projectId,
    required this.requesterId,
    required this.language,
    required this.key,
    this.comment,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String requesterId;
  final String language;
  final String key;
  final String? comment;
  ReviewStatus status;
  final DateTime createdAt;
  final List<_ReviewDecision> decisions = [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'requesterId': requesterId,
      'language': language,
      'key': key,
      'comment': comment,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'decisions': decisions.map((d) => d.toJson()).toList(),
    };
  }
}

class _ReviewDecision {
  _ReviewDecision({
    required this.reviewerId,
    required this.decision,
    this.comment,
    required this.timestamp,
  });

  final String reviewerId;
  final ReviewDecision decision;
  final String? comment;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'reviewerId': reviewerId,
      'decision': decision.name,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class _TranslationLock {
  _TranslationLock({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.language,
    required this.key,
    required this.acquiredAt,
    required this.expiresAt,
  });

  _TranslationLock.empty()
      : id = '',
        projectId = '',
        userId = '',
        language = '',
        key = '',
        acquiredAt = DateTime.now(),
        expiresAt = DateTime.now();

  final String id;
  final String projectId;
  final String userId;
  final String language;
  final String key;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'language': language,
      'key': key,
      'acquiredAt': acquiredAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

class _TranslationConflict {
  _TranslationConflict({
    required this.key,
    required this.language,
    required this.existingValue,
    required this.newValue,
    required this.existingUserId,
    required this.newUserId,
    required this.existingTimestamp,
    required this.newTimestamp,
  });

  final String key;
  final String language;
  final String existingValue;
  final String newValue;
  final String existingUserId;
  final String newUserId;
  final DateTime existingTimestamp;
  final DateTime newTimestamp;

  bool get isConflicting => existingValue != newValue;
}

class _ConflictResolution {
  _ConflictResolution({
    required this.accepted,
    required this.reason,
  });

  final bool accepted;
  final String reason;
}
