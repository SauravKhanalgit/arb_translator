import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:arb_translator_gen_z/arb_translator_gen_z.dart';
import 'package:arb_translator_gen_z/src/logging/translator_logger.dart';

/// Web server for the ARB Translator GUI.
class WebServer {
  /// Creates a [WebServer] with the given configuration.
  WebServer({
    required this.config,
    this.port = 8080,
    this.host = 'localhost',
  }) {
    _logger = TranslatorLogger()..initialize(config.logLevel);
    _translator = LocalizationTranslator(config);
  }

  /// Configuration for the translator.
  final TranslatorConfig config;

  /// Port to run the server on.
  final int port;

  /// Host to bind to.
  final String host;

  late final TranslatorLogger _logger;
  late final LocalizationTranslator _translator;
  HttpServer? _server;

  /// Start the web server.
  Future<void> start() async {
    final app = Router();

    // Static file serving
    final staticHandler = createStaticHandler('web', defaultDocument: 'index.html');
    app.mount('/static/', staticHandler);

    // API routes
    app.get('/api/health', _healthCheck);
    app.post('/api/upload', _uploadFile);
    app.post('/api/translate', _translateFile);
    app.get('/api/languages', _getLanguages);
    app.get('/api/analytics', _getAnalytics);
    app.post('/api/validate', _validateFile);

    // Catch-all for SPA routing
    app.get('/<path|[^]*>', _serveIndex);

    _server = await shelf_io.serve(app, host, port);
    _logger.info('🌐 Web GUI server started at http://$host:$port');
    _logger.info('📱 Open your browser and visit the URL above');
  }

  /// Stop the web server.
  Future<void> stop() async {
    await _server?.close();
    _translator.dispose();
    _logger.info('🛑 Web server stopped');
  }

  /// Health check endpoint.
  Response _healthCheck(Request request) {
    return Response.ok(
      json.encode({
        'status': 'healthy',
        'version': '3.2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'features': [
          'ai_translation',
          'context_aware',
          'multi_format',
          'analytics',
          'compliance'
        ]
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Upload file endpoint.
  Future<Response> _uploadFile(Request request) async {
    try {
      // For simplicity, expect JSON content with base64 encoded file
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;

      final fileName = data['fileName'] as String?;
      final fileData = data['fileData'] as String?; // Base64 encoded
      final fileType = data['fileType'] as String? ?? 'arb';

      if (fileName == null || fileData == null) {
        return Response.badRequest(body: json.encode({'error': 'Missing file data'}));
      }

      // Decode base64 content
      final bytes = base64.decode(fileData);
      final content = utf8.decode(bytes);
      final parsedContent = json.decode(content) as Map<String, dynamic>;

      // Analyze the file
      final analysis = ArbHelper.analyzeArbFiles({'uploaded': parsedContent});

      return Response.ok(
        json.encode({
          'fileName': fileName,
          'fileType': fileType,
          'content': parsedContent,
          'analysis': {
            'totalKeys': analysis.fileAnalysis['uploaded']?.totalKeys ?? 0,
            'missingKeys': analysis.fileAnalysis['uploaded']?.missingKeys.length ?? 0,
            'completeness': analysis.fileAnalysis['uploaded']?.completenessPercentage ?? 0.0,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Upload error', e);
      return Response.internalServerError(
        body: json.encode({'error': 'Upload failed: $e'}),
      );
    }
  }

  /// Translate file endpoint.
  Future<Response> _translateFile(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;

      final sourceContent = data['content'] as Map<String, dynamic>;
      final targetLanguages = List<String>.from(data['languages'] as Iterable? ?? []);

      if (targetLanguages.isEmpty) {
        return Response.badRequest(body: json.encode({'error': 'No target languages specified'}));
      }

      // Create temporary file for translation
      final tempDir = Directory.systemTemp.createTempSync('arb_web_');
      final sourcePath = '${tempDir.path}/source.arb';
      final sourceFileObj = File(sourcePath);
      await sourceFileObj.writeAsString(json.encode(sourceContent));

      final results = <String, Map<String, dynamic>>{};

      for (final lang in targetLanguages) {
        try {
          final targetPath = await _translator.generateForLanguage(sourcePath, lang);

          // Read the translated file
          final translatedContent = json.decode(await File(targetPath).readAsString());

          results[lang] = {
            'success': true,
            'content': translatedContent,
            'filePath': targetPath,
          };
        } catch (e) {
          _logger.error('Translation failed for $lang', e);
          results[lang] = {
            'success': false,
            'error': e.toString(),
          };
        }
      }

      // Cleanup temp files
      await tempDir.delete(recursive: true);

      return Response.ok(
        json.encode({
          'results': results,
          'summary': {
            'totalLanguages': targetLanguages.length,
            'successful': results.values.where((r) => r['success'] == true).length,
            'failed': results.values.where((r) => r['success'] == false).length,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Translation error', e);
      return Response.internalServerError(
        body: json.encode({'error': 'Translation failed: $e'}),
      );
    }
  }

  /// Get supported languages endpoint.
  Response _getLanguages(Request request) {
    final languages = supportedLanguages.values.map((lang) => {
      'code': lang.code,
      'name': lang.name,
      'nativeName': lang.nativeName,
      'region': lang.region,
      'rtl': lang.isRightToLeft,
    }).toList();

    return Response.ok(
      json.encode({
        'languages': languages,
        'popular': popularLanguageCodes,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get analytics data endpoint.
  Future<Response> _getAnalytics(Request request) async {
    try {
      // Placeholder analytics data (would integrate with actual analytics in production)
      final memoryStats = {
        'totalEntries': 0,
        'cacheHits': 0,
        'hitRate': 0.0,
      };

      final providerStats = {
        'total_providers': 5,
        'available_providers': 3,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        json.encode({
          'memory': memoryStats,
          'providers': providerStats,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Analytics unavailable: $e'}),
      );
    }
  }

  /// Validate file endpoint.
  Future<Response> _validateFile(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      final content = data['content'] as Map<String, dynamic>;

      final issues = ArbHelper.validateArbContent(content);
      final analysis = ArbHelper.analyzeArbFiles({'validated': content});

      return Response.ok(
        json.encode({
          'valid': issues.isEmpty,
          'issues': issues,
          'analysis': {
            'totalKeys': analysis.fileAnalysis['validated']?.totalKeys ?? 0,
            'missingKeys': analysis.fileAnalysis['validated']?.missingKeys.length ?? 0,
            'completeness': analysis.fileAnalysis['validated']?.completenessPercentage ?? 0.0,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Validation failed: $e'}),
      );
    }
  }

  /// Serve the main index page for SPA routing.
  Response _serveIndex(Request request) {
    try {
      final indexFile = File('web/index.html');
      if (indexFile.existsSync()) {
        return Response.ok(
          indexFile.openRead(),
          headers: {'Content-Type': 'text/html'},
        );
      }
    } catch (e) {
      // Fall through to static handler
    }

    return Response.notFound('Page not found');
  }
}
