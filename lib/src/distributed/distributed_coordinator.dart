import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Distributed processing coordinator for large-scale translation projects.
/// Splits work across multiple workers and coordinates results.
class DistributedCoordinator {
  /// Creates a distributed coordinator.
  DistributedCoordinator({
    required this.config,
    this.maxWorkers = 4,
    this.taskTimeout = const Duration(minutes: 10),
    this.enableLoadBalancing = true,
  }) {
    _logger = TranslatorLogger()..initialize(config.logLevel);
    _workers = <DistributedWorker>[];
    _taskQueue = Queue<_TranslationTask>();
    _activeTasks = <String, _TranslationTask>{};
    _completedTasks = <String, _TranslationTask>{};
    _failedTasks = <String, _TranslationTask>{};
  }

  /// Configuration for the translator.
  final TranslatorConfig config;

  /// Maximum number of concurrent workers.
  final int maxWorkers;

  /// Timeout for individual tasks.
  final Duration taskTimeout;

  /// Whether to enable load balancing between workers.
  final bool enableLoadBalancing;

  late final TranslatorLogger _logger;
  late final List<DistributedWorker> _workers;
  late final Queue<_TranslationTask> _taskQueue;
  late final Map<String, _TranslationTask> _activeTasks;
  late final Map<String, _TranslationTask> _completedTasks;
  late final Map<String, _TranslationTask> _failedTasks;

  /// Translation statistics.
  int get totalTasks => _taskQueue.length + _activeTasks.length + _completedTasks.length + _failedTasks.length;
  int get pendingTasks => _taskQueue.length;
  int get activeTasks => _activeTasks.length;
  int get completedTasks => _completedTasks.length;
  int get failedTasks => _failedTasks.length;

  /// Performance metrics.
  double get completionRate => totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
  Duration get averageTaskTime {
    if (_completedTasks.isEmpty) return Duration.zero;

    final totalTime = _completedTasks.values.fold<Duration>(
      Duration.zero,
      (sum, task) => sum + (task.completedAt!.difference(task.startedAt!)),
    );

    return totalTime ~/ _completedTasks.length;
  }

  /// Initialize the distributed coordinator.
  Future<void> initialize() async {
    _logger.info('🔄 Initializing distributed coordinator...');
    _logger.info('⚙️  Max workers: $maxWorkers');
    _logger.info('⏰ Task timeout: ${taskTimeout.inMinutes} minutes');
    _logger.info('⚖️  Load balancing: $enableLoadBalancing');

    // Start worker management
    _startWorkerManagement();

    _logger.info('✅ Distributed coordinator initialized');
  }

  /// Add a translation job to be processed.
  Future<String> addTranslationJob({
    required String sourceFile,
    required List<String> targetLanguages,
    required String jobId,
    Map<String, dynamic>? context,
    int priority = 0,
  }) async {
    // Split large jobs into smaller tasks
    final tasks = _splitJobIntoTasks(
      sourceFile: sourceFile,
      targetLanguages: targetLanguages,
      jobId: jobId,
      context: context,
      priority: priority,
    );

    for (final task in tasks) {
      _addTaskToQueue(task);
    }

    _logger.info('📋 Added job $jobId with ${tasks.length} tasks');
    return jobId;
  }

  /// Wait for all tasks in a job to complete.
  Future<Map<String, dynamic>> waitForJobCompletion(String jobId) async {
    final completer = Completer<Map<String, dynamic>>();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final jobTasks = _getJobTasks(jobId);

      if (jobTasks.isEmpty) {
        timer.cancel();
        completer.complete({'error': 'Job not found'});
        return;
      }

      final allCompleted = jobTasks.every((task) =>
        task.status == _TaskStatus.completed || task.status == _TaskStatus.failed
      );

      if (allCompleted) {
        timer.cancel();

        final completed = jobTasks.where((task) => task.status == _TaskStatus.completed).length;
        final failed = jobTasks.where((task) => task.status == _TaskStatus.failed).length;
        final total = jobTasks.length;

        final result = {
          'jobId': jobId,
          'totalTasks': total,
          'completedTasks': completed,
          'failedTasks': failed,
          'completionRate': total == 0 ? 0.0 : completed / total,
          'averageTaskTime': _calculateJobAverageTime(jobTasks),
          'tasks': jobTasks.map((task) => task.toJson()).toList(),
        };

        completer.complete(result);
      }
    });

    return completer.future;
  }

  /// Get the status of a job.
  Map<String, dynamic> getJobStatus(String jobId) {
    final jobTasks = _getJobTasks(jobId);

    if (jobTasks.isEmpty) {
      return {'error': 'Job not found'};
    }

    final completed = jobTasks.where((task) => task.status == _TaskStatus.completed).length;
    final failed = jobTasks.where((task) => task.status == _TaskStatus.failed).length;
    final active = jobTasks.where((task) => task.status == _TaskStatus.active).length;
    final pending = jobTasks.where((task) => task.status == _TaskStatus.pending).length;
    final total = jobTasks.length;

    return {
      'jobId': jobId,
      'totalTasks': total,
      'completedTasks': completed,
      'failedTasks': failed,
      'activeTasks': active,
      'pendingTasks': pending,
      'completionRate': total == 0 ? 0.0 : completed / total,
      'isComplete': completed + failed == total,
    };
  }

  /// Get overall coordinator statistics.
  Map<String, dynamic> getStatistics() {
    final workerStats = _workers.map((worker) => worker.getStatistics()).toList();

    return {
      'totalTasks': totalTasks,
      'pendingTasks': pendingTasks,
      'activeTasks': activeTasks,
      'completedTasks': completedTasks,
      'failedTasks': failedTasks,
      'completionRate': completionRate,
      'averageTaskTime': averageTaskTime.inMilliseconds,
      'workers': workerStats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Shutdown the coordinator and all workers.
  Future<void> shutdown() async {
    _logger.info('🛑 Shutting down distributed coordinator...');

    // Cancel all pending tasks
    _taskQueue.clear();

    // Stop all workers
    for (final worker in _workers) {
      await worker.stop();
    }
    _workers.clear();

    _logger.info('✅ Distributed coordinator shutdown complete');
  }

  /// Split a large translation job into smaller tasks.
  List<_TranslationTask> _splitJobIntoTasks({
    required String sourceFile,
    required List<String> targetLanguages,
    required String jobId,
    Map<String, dynamic>? context,
    int priority = 0,
  }) {
    final tasks = <_TranslationTask>[];

    // For large language sets, split by language groups
    const maxLanguagesPerTask = 5;
    final languageGroups = <List<String>>[];

    for (var i = 0; i < targetLanguages.length; i += maxLanguagesPerTask) {
      final end = min(i + maxLanguagesPerTask, targetLanguages.length);
      languageGroups.add(targetLanguages.sublist(i, end));
    }

    for (var i = 0; i < languageGroups.length; i++) {
      final taskId = '$jobId-task-$i';
      final task = _TranslationTask(
        id: taskId,
        jobId: jobId,
        sourceFile: sourceFile,
        targetLanguages: languageGroups[i],
        context: context,
        priority: priority,
        createdAt: DateTime.now(),
      );

      tasks.add(task);
    }

    return tasks;
  }

  /// Add a task to the processing queue.
  void _addTaskToQueue(_TranslationTask task) {
    // Insert based on priority (higher priority first)
    var inserted = false;
    var i = 0;
    for (final queuedTask in _taskQueue) {
      if (task.priority > queuedTask.priority) {
        _taskQueue.addFirst(task);
        inserted = true;
        break;
      }
      i++;
    }

    if (!inserted) {
      _taskQueue.addLast(task);
    }
  }

  /// Get all tasks for a specific job.
  List<_TranslationTask> _getJobTasks(String jobId) {
    final allTasks = <_TranslationTask>[];
    allTasks.addAll(_taskQueue.where((task) => task.jobId == jobId));
    allTasks.addAll(_activeTasks.values.where((task) => task.jobId == jobId));
    allTasks.addAll(_completedTasks.values.where((task) => task.jobId == jobId));
    allTasks.addAll(_failedTasks.values.where((task) => task.jobId == jobId));
    return allTasks;
  }

  /// Calculate average completion time for job tasks.
  Duration _calculateJobAverageTime(List<_TranslationTask> tasks) {
    final completedTasks = tasks.where((task) => task.status == _TaskStatus.completed && task.completedAt != null && task.startedAt != null);

    if (completedTasks.isEmpty) return Duration.zero;

    final totalTime = completedTasks.fold<Duration>(
      Duration.zero,
      (sum, task) => sum + (task.completedAt!.difference(task.startedAt!)),
    );

    return totalTime ~/ completedTasks.length;
  }

  /// Start worker management and task distribution.
  void _startWorkerManagement() {
    // Initialize workers
    for (var i = 0; i < maxWorkers; i++) {
      final worker = DistributedWorker(
        id: 'worker-$i',
        config: config,
        coordinator: this,
        logger: _logger,
      );
      _workers.add(worker);
      worker.start();
    }

    // Start task distribution
    Timer.periodic(const Duration(seconds: 2), (_) {
      _distributeTasks();
    });

    // Start cleanup of timed-out tasks
    Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupTimedOutTasks();
    });
  }

  /// Distribute pending tasks to available workers.
  void _distributeTasks() {
    if (_taskQueue.isEmpty) return;

    // Find available workers
    final availableWorkers = _workers.where((worker) => worker.isAvailable).toList();

    if (availableWorkers.isEmpty) return;

    // Sort workers by load if load balancing is enabled
    if (enableLoadBalancing) {
      availableWorkers.sort((a, b) => a.activeTasks.compareTo(b.activeTasks));
    }

    // Assign tasks to workers
    for (final worker in availableWorkers) {
      if (_taskQueue.isEmpty) break;

      final task = _taskQueue.removeFirst();
      task.status = _TaskStatus.active;
      task.startedAt = DateTime.now();
      task.assignedWorker = worker.id;

      _activeTasks[task.id] = task;
      worker.assignTask(task);

      _logger.debug('📤 Assigned task ${task.id} to worker ${worker.id}');
    }
  }

  /// Clean up tasks that have timed out.
  void _cleanupTimedOutTasks() {
    final now = DateTime.now();
    final timedOutTasks = <_TranslationTask>[];

    for (final task in _activeTasks.values) {
      if (task.startedAt != null && now.difference(task.startedAt!) > taskTimeout) {
        timedOutTasks.add(task);
      }
    }

    for (final task in timedOutTasks) {
      _logger.warning('⏰ Task ${task.id} timed out after ${taskTimeout.inMinutes} minutes');
      _handleTaskFailure(task, 'Task timeout');
    }
  }

  /// Handle task completion from a worker.
  void _handleTaskCompletion(_TranslationTask task, Map<String, dynamic> result) {
    task.status = _TaskStatus.completed;
    task.completedAt = DateTime.now();
    task.result = result;

    _activeTasks.remove(task.id);
    _completedTasks[task.id] = task;

    _logger.info('✅ Task ${task.id} completed successfully');
  }

  /// Handle task failure from a worker.
  void _handleTaskFailure(_TranslationTask task, String error) {
    task.status = _TaskStatus.failed;
    task.completedAt = DateTime.now();
    task.error = error;

    _activeTasks.remove(task.id);
    _failedTasks[task.id] = task;

    _logger.error('❌ Task ${task.id} failed: $error');
  }
}

/// Distributed worker that processes translation tasks.
class DistributedWorker {
  /// Creates a distributed worker.
  DistributedWorker({
    required this.id,
    required this.config,
    required DistributedCoordinator coordinator,
    required TranslatorLogger logger,
  }) : _coordinator = coordinator,
       _logger = logger;

  /// Worker identifier.
  final String id;

  /// Configuration for the translator.
  final TranslatorConfig config;

  final DistributedCoordinator _coordinator;
  final TranslatorLogger _logger;

  late final LocalizationTranslator _translator;
  final List<_TranslationTask> _assignedTasks = [];
  bool _isRunning = false;
  Timer? _processingTimer;

  /// Whether this worker is available for new tasks.
  bool get isAvailable => _isRunning && _assignedTasks.length < 3; // Max 3 concurrent tasks

  /// Number of active tasks.
  int get activeTasks => _assignedTasks.length;

  /// Start the worker.
  void start() {
    _translator = LocalizationTranslator(config);
    _isRunning = true;

    _processingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _processTasks();
    });

    _logger.info('🚀 Worker $id started');
  }

  /// Stop the worker.
  Future<void> stop() async {
    _isRunning = false;
    _processingTimer?.cancel();

    // Wait for current tasks to complete
    while (_assignedTasks.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _translator.dispose();
    _logger.info('🛑 Worker $id stopped');
  }

  /// Assign a task to this worker.
  void assignTask(_TranslationTask task) {
    _assignedTasks.add(task);
    _logger.debug('📥 Worker $id received task ${task.id}');
  }

  /// Get worker statistics.
  Map<String, dynamic> getStatistics() {
    return {
      'workerId': id,
      'isRunning': _isRunning,
      'activeTasks': activeTasks,
      'available': isAvailable,
      'uptime': DateTime.now().difference(DateTime.now()), // TODO: Track actual uptime
    };
  }

  /// Process assigned tasks.
  Future<void> _processTasks() async {
    if (!_isRunning || _assignedTasks.isEmpty) return;

    // Process one task at a time to avoid overwhelming the worker
    final task = _assignedTasks.removeAt(0);

    try {
      _logger.debug('🔄 Worker $id processing task ${task.id}');

      final result = await _executeTranslationTask(task);
      _coordinator._handleTaskCompletion(task, result);

    } catch (e) {
      _coordinator._handleTaskFailure(task, e.toString());
    }
  }

  /// Execute a translation task.
  Future<Map<String, dynamic>> _executeTranslationTask(_TranslationTask task) async {
    final results = <String, dynamic>{};
    final startTime = DateTime.now();

    for (final language in task.targetLanguages) {
      try {
        final targetPath = await _translator.generateForLanguage(task.sourceFile, language);

        // Read the translated content
        final content = await File(targetPath).readAsString();
        final parsedContent = json.decode(content);

        results[language] = {
          'success': true,
          'filePath': targetPath,
          'content': parsedContent,
          'translatedAt': DateTime.now().toIso8601String(),
        };

      } catch (e) {
        results[language] = {
          'success': false,
          'error': e.toString(),
          'failedAt': DateTime.now().toIso8601String(),
        };
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    return {
      'taskId': task.id,
      'jobId': task.jobId,
      'results': results,
      'duration': duration.inMilliseconds,
      'processedAt': endTime.toIso8601String(),
      'workerId': id,
    };
  }
}

/// Internal representation of a translation task.
enum _TaskStatus { pending, active, completed, failed }

class _TranslationTask {
  _TranslationTask({
    required this.id,
    required this.jobId,
    required this.sourceFile,
    required this.targetLanguages,
    this.context,
    this.priority = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String jobId;
  final String sourceFile;
  final List<String> targetLanguages;
  final Map<String, dynamic>? context;
  final int priority;
  final DateTime createdAt;

  String? assignedWorker;
  DateTime? startedAt;
  DateTime? completedAt;
  Map<String, dynamic>? result;
  String? error;

  _TaskStatus status = _TaskStatus.pending;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'sourceFile': sourceFile,
      'targetLanguages': targetLanguages,
      'priority': priority,
      'status': status.name,
      'assignedWorker': assignedWorker,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'duration': startedAt != null && completedAt != null
        ? completedAt!.difference(startedAt!).inMilliseconds
        : null,
      'result': result,
      'error': error,
    };
  }
}
