import 'dart:convert';
import 'dart:io';
import 'package:arb_translator_gen_z/src/config/translator_config.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Represents a plugin for the ARB translator.
abstract class TranslatorPlugin {
  /// The unique identifier for this plugin.
  String get id;

  /// The human-readable name of the plugin.
  String get name;

  /// The version of the plugin.
  String get version;

  /// A description of what this plugin does.
  String get description;

  /// Initialize the plugin with configuration.
  Future<void> initialize(TranslatorConfig config, TranslatorLogger logger);

  /// Cleanup resources when the plugin is unloaded.
  Future<void> dispose();
}

/// Hook points in the translation process where plugins can intervene.
enum PluginHook {
  /// Called before translation starts.
  preTranslation,

  /// Called after translation is complete but before saving.
  postTranslation,

  /// Called when validating ARB files.
  validation,

  /// Called when analyzing translation completeness.
  analysis,

  /// Called during CLI command execution.
  cliCommand,

  /// Called when loading configuration.
  configLoad,

  /// Called when saving configuration.
  configSave,

  /// Called when initializing translation memory.
  memoryInit,

  /// Called when a translation is added to memory.
  memoryAdd,

  /// Called when searching translation memory.
  memorySearch,
}

/// Context information passed to plugin hooks.
class PluginContext {
  /// Creates a [PluginContext] with the given data.
  PluginContext({
    this.sourceText,
    this.translatedText,
    this.sourceLang,
    this.targetLang,
    this.filePath,
    this.metadata,
    this.cliArgs,
    this.customData,
  });

  /// Source text being translated.
  final String? sourceText;

  /// Translated text result.
  final String? translatedText;

  /// Source language code.
  final String? sourceLang;

  /// Target language code.
  final String? targetLang;

  /// File path being processed.
  final String? filePath;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// CLI arguments (for CLI command hooks).
  final List<String>? cliArgs;

  /// Custom data for plugin-specific use.
  final Map<String, dynamic>? customData;

  /// Creates a copy with updated fields.
  PluginContext copyWith({
    String? sourceText,
    String? translatedText,
    String? sourceLang,
    String? targetLang,
    String? filePath,
    Map<String, dynamic>? metadata,
    List<String>? cliArgs,
    Map<String, dynamic>? customData,
  }) {
    return PluginContext(
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      filePath: filePath ?? this.filePath,
      metadata: metadata ?? this.metadata,
      cliArgs: cliArgs ?? this.cliArgs,
      customData: customData ?? this.customData,
    );
  }
}

/// Result returned by plugin hook execution.
class PluginResult {
  /// Creates a [PluginResult] with the given data.
  const PluginResult({
    this.success = true,
    this.modifiedContext,
    this.errorMessage,
    this.shouldContinue = true,
  });

  /// Whether the hook executed successfully.
  final bool success;

  /// Modified context (if the plugin changed it).
  final PluginContext? modifiedContext;

  /// Error message if the hook failed.
  final String? errorMessage;

  /// Whether processing should continue after this hook.
  final bool shouldContinue;
}

/// Interface for plugins that implement specific hooks.
abstract class HookPlugin implements TranslatorPlugin {
  /// List of hooks this plugin implements.
  List<PluginHook> get supportedHooks;

  /// Execute a hook with the given context.
  Future<PluginResult> executeHook(PluginHook hook, PluginContext context);
}

/// Plugin for custom translation providers.
abstract class TranslationProviderPlugin implements TranslatorPlugin {
  /// Get the translation provider implementation.
  dynamic get provider;

  /// Whether this provider is available.
  bool get isAvailable;
}

/// Plugin for custom validation rules.
abstract class ValidationPlugin implements TranslatorPlugin {
  /// Validate the given content and return issues.
  Future<List<String>> validate(
    Map<String, dynamic> content,
    String filePath,
  );
}

/// Plugin for custom analytics and reporting.
abstract class AnalyticsPlugin implements TranslatorPlugin {
  /// Track an event with optional properties.
  Future<void> trackEvent(String event, Map<String, dynamic>? properties);

  /// Get analytics data.
  Future<Map<String, dynamic>> getAnalytics();
}

/// Plugin manager that handles loading, unloading, and executing plugins.
class PluginManager {
  /// Creates a [PluginManager] with the given logger.
  PluginManager(this.logger);

  /// Logger for plugin operations.
  final TranslatorLogger logger;

  /// Registered plugins.
  final Map<String, TranslatorPlugin> _plugins = {};

  /// Hook subscribers.
  final Map<PluginHook, List<HookPlugin>> _hookSubscribers = {};

  /// Whether the plugin system is initialized.
  bool _initialized = false;

  /// Initialize the plugin system.
  Future<void> initialize(TranslatorConfig config) async {
    if (_initialized) return;

    logger.info('Initializing plugin system...');

    // Load built-in plugins
    await _loadBuiltInPlugins(config);

    // Load external plugins
    await _loadExternalPlugins(config);

    _initialized = true;
    logger.info('Plugin system initialized with ${_plugins.length} plugins');
  }

  /// Register a plugin.
  Future<void> registerPlugin(TranslatorPlugin plugin, TranslatorConfig config) async {
    if (_plugins.containsKey(plugin.id)) {
      logger.warning('Plugin ${plugin.id} is already registered');
      return;
    }

    try {
      await plugin.initialize(config, logger);
      _plugins[plugin.id] = plugin;

      // Register hook subscribers
      if (plugin is HookPlugin) {
        for (final hook in plugin.supportedHooks) {
          _hookSubscribers.putIfAbsent(hook, () => []).add(plugin);
        }
      }

      logger.info('Registered plugin: ${plugin.name} (${plugin.id}) v${plugin.version}');
    } catch (e) {
      logger.error('Failed to register plugin ${plugin.id}: $e');
    }
  }

  /// Unregister a plugin.
  Future<void> unregisterPlugin(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin != null) {
      try {
        await plugin.dispose();

        // Remove from hook subscribers
        for (final subscribers in _hookSubscribers.values) {
          subscribers.removeWhere((p) => p.id == pluginId);
        }

        logger.info('Unregistered plugin: ${plugin.name} (${plugin.id})');
      } catch (e) {
        logger.error('Error disposing plugin ${pluginId}: $e');
      }
    }
  }

  /// Execute all plugins for a specific hook.
  Future<PluginContext> executeHook(
    PluginHook hook,
    PluginContext context,
  ) async {
    final subscribers = _hookSubscribers[hook] ?? [];

    if (subscribers.isEmpty) {
      return context;
    }

    var currentContext = context;

    for (final plugin in subscribers) {
      try {
        logger.debug('Executing hook $hook for plugin ${plugin.id}');
        final result = await plugin.executeHook(hook, currentContext);

        if (!result.success) {
          logger.warning('Plugin ${plugin.id} failed for hook $hook: ${result.errorMessage}');
          if (!result.shouldContinue) {
            break;
          }
        }

        if (result.modifiedContext != null) {
          currentContext = result.modifiedContext!;
          logger.debug('Plugin ${plugin.id} modified context for hook $hook');
        }
      } catch (e) {
        logger.error('Error executing hook $hook for plugin ${plugin.id}: $e');
      }
    }

    return currentContext;
  }

  /// Get all registered plugins.
  Map<String, TranslatorPlugin> get plugins => Map.unmodifiable(_plugins);

  /// Get plugins of a specific type.
  List<T> getPluginsOfType<T extends TranslatorPlugin>() {
    return _plugins.values.whereType<T>().toList();
  }

  /// Get plugin statistics.
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{
      'totalPlugins': _plugins.length,
      'hookSubscribers': <String, int>{},
      'pluginTypes': <String, int>{},
    };

    for (final entry in _hookSubscribers.entries) {
      stats['hookSubscribers'][entry.key.name] = entry.value.length;
    }

    for (final plugin in _plugins.values) {
      final type = plugin.runtimeType.toString();
      stats['pluginTypes'][type] = (stats['pluginTypes'][type] ?? 0) + 1;
    }

    return stats;
  }

  /// Dispose of all plugins and cleanup.
  Future<void> dispose() async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.dispose();
      } catch (e) {
        logger.error('Error disposing plugin ${plugin.id}: $e');
      }
    }

    _plugins.clear();
    _hookSubscribers.clear();
    _initialized = false;

    logger.info('Plugin system disposed');
  }

  Future<void> _loadBuiltInPlugins(TranslatorConfig config) async {
    // Register built-in plugins here
    // For now, this is empty but can be extended
    logger.debug('No built-in plugins to load');
  }

  Future<void> _loadExternalPlugins(TranslatorConfig config) async {
    // Look for plugins in standard locations
    final pluginDirs = [
      Directory('plugins'),
      Directory('.arb_translator/plugins'),
      Directory('${Platform.environment['HOME']}/.arb_translator/plugins'),
    ];

    for (final dir in pluginDirs) {
      if (await dir.exists()) {
        await _scanPluginDirectory(dir, config);
      }
    }
  }

  Future<void> _scanPluginDirectory(Directory dir, TranslatorConfig config) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.yaml')) {
          await _loadPluginFromConfig(entity, config);
        }
      }
    } catch (e) {
      logger.warning('Error scanning plugin directory ${dir.path}: $e');
    }
  }

  Future<void> _loadPluginFromConfig(File configFile, TranslatorConfig config) async {
    try {
      final content = await configFile.readAsString();
      final pluginConfig = json.decode(content) as Map<String, dynamic>;

      final pluginId = pluginConfig['id'] as String?;
      final pluginClass = pluginConfig['class'] as String?;

      if (pluginId == null || pluginClass == null) {
        logger.warning('Invalid plugin config in ${configFile.path}');
        return;
      }

      // Dynamic plugin loading would go here
      // For now, just log that we found a plugin
      logger.info('Found plugin config: $pluginId ($pluginClass)');
    } catch (e) {
      logger.warning('Error loading plugin from ${configFile.path}: $e');
    }
  }
}

/// Example plugin: Translation Quality Reporter
class QualityReporterPlugin implements HookPlugin {
  @override
  String get id => 'quality_reporter';

  @override
  String get name => 'Translation Quality Reporter';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Reports translation quality metrics and generates quality reports';

  @override
  List<PluginHook> get supportedHooks => [
    PluginHook.postTranslation,
    PluginHook.analysis,
  ];

  late TranslatorLogger _logger;
  final List<Map<String, dynamic>> _qualityReports = [];

  @override
  Future<void> initialize(TranslatorConfig config, TranslatorLogger logger) async {
    _logger = logger;
    _logger.info('Quality Reporter Plugin initialized');
  }

  @override
  Future<void> dispose() async {
    // Save final report
    if (_qualityReports.isNotEmpty) {
      _logger.info('Quality Reporter: Generated ${_qualityReports.length} quality reports');
    }
  }

  @override
  Future<PluginResult> executeHook(PluginHook hook, PluginContext context) async {
    switch (hook) {
      case PluginHook.postTranslation:
        return await _handlePostTranslation(context);
      case PluginHook.analysis:
        return await _handleAnalysis(context);
      default:
        return const PluginResult();
    }
  }

  Future<PluginResult> _handlePostTranslation(PluginContext context) async {
    final qualityScore = context.metadata?['qualityScore'] as double?;
    final provider = context.metadata?['provider'] as String?;

    if (qualityScore != null && provider != null) {
      final report = {
        'timestamp': DateTime.now().toIso8601String(),
        'sourceText': context.sourceText,
        'translatedText': context.translatedText,
        'provider': provider,
        'qualityScore': qualityScore,
        'sourceLang': context.sourceLang,
        'targetLang': context.targetLang,
        'filePath': context.filePath,
      };

      _qualityReports.add(report);

      if (qualityScore < 0.7) {
        _logger.warning('Low quality translation detected: ${qualityScore.toStringAsFixed(2)}');
      }
    }

    return const PluginResult();
  }

  Future<PluginResult> _handleAnalysis(PluginContext context) async {
    if (_qualityReports.isNotEmpty) {
      final averageQuality = _qualityReports
          .map((r) => r['qualityScore'] as double)
          .reduce((a, b) => a + b) / _qualityReports.length;

      _logger.info('Quality Analysis: Average score ${(averageQuality * 100).round()}% '
          'across ${_qualityReports.length} translations');

      // Group by provider
      final byProvider = <String, List<Map<String, dynamic>>>{};
      for (final report in _qualityReports) {
        final provider = report['provider'] as String;
        byProvider.putIfAbsent(provider, () => []).add(report);
      }

      for (final entry in byProvider.entries) {
        final provider = entry.key;
        final reports = entry.value;
        final avgScore = reports
            .map((r) => r['qualityScore'] as double)
            .reduce((a, b) => a + b) / reports.length;

        _logger.info('  $provider: ${(avgScore * 100).round()}% (${reports.length} translations)');
      }
    }

    return const PluginResult();
  }
}

/// Example plugin: Custom Validation Rules
class CustomValidationPlugin implements ValidationPlugin {
  @override
  String get id => 'custom_validator';

  @override
  String get name => 'Custom Validation Plugin';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Provides custom validation rules for ARB files';

  late TranslatorLogger _logger;
  final List<RegExp> _forbiddenPatterns = [
    RegExp(r'\b(?:shit|damn|hell)\b', caseSensitive: false),
    RegExp(r'\b(?:fuck|crap|ass)\b', caseSensitive: false),
  ];

  @override
  Future<void> initialize(TranslatorConfig config, TranslatorLogger logger) async {
    _logger = logger;
    _logger.info('Custom Validation Plugin initialized');
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose
  }

  @override
  Future<List<String>> validate(
    Map<String, dynamic> content,
    String filePath,
  ) async {
    final issues = <String>[];

    for (final entry in content.entries) {
      if (entry.key.startsWith('@')) continue; // Skip metadata

      final value = entry.value?.toString() ?? '';
      if (value.isEmpty) continue;

      // Check for forbidden words
      for (final pattern in _forbiddenPatterns) {
        if (pattern.hasMatch(value)) {
          issues.add('Forbidden word detected in "${entry.key}": ${pattern.pattern}');
        }
      }

      // Check for proper punctuation
      if (!value.contains(RegExp(r'[.!?]$'))) {
        issues.add('Missing punctuation in "${entry.key}"');
      }

      // Check for consistent placeholder usage
      final placeholders = RegExp(r'\{([^}]+)\}').allMatches(value);
      final placeholderNames = placeholders.map((m) => m.group(1)).toSet();

      if (placeholderNames.length > 5) {
        issues.add('Too many placeholders in "${entry.key}" (${placeholderNames.length})');
      }
    }

    return issues;
  }
}
