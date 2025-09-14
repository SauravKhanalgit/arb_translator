import 'dart:convert';
import 'dart:io';

/// Reads an ARB file from the given [path] and returns its content as a Map.
///
/// Example:
/// ```dart
/// final content = await readArbFile('lib/l10n/app_en.arb');
/// print(content['appTitle']); // prints the title string
/// ```
///
/// [path]: The file path to the ARB file.
///
/// Returns a [Future<Map<String, dynamic>>] containing the key-value pairs
/// from the ARB file.
///
/// Throws [Exception] if the file does not exist or cannot be read.
Future<Map<String, dynamic>> readArbFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) throw Exception('ARB file not found: $path');
  final content = await file.readAsString();
  return json.decode(content);
}

/// Writes the given [content] Map to an ARB file at the specified [path].
///
/// The output JSON is pretty-printed with 2-space indentation for readability.
///
/// Example:
/// ```dart
/// await writeArbFile('lib/l10n/app_fr.arb', {'appTitle': 'Mon App'});
/// ```
///
/// [path]: The file path where the ARB file will be written.
/// [content]: A Map containing the key-value pairs to write.
///
/// Returns a [Future<void>] that completes when the file has been written.
Future<void> writeArbFile(String path, Map<String, dynamic> content) async {
  final file = File(path);
  final encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(content));
}
