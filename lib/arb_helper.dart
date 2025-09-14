import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> readArbFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) throw Exception('ARB file not found: $path');
  final content = await file.readAsString();
  return json.decode(content);
}

Future<void> writeArbFile(String path, Map<String, dynamic> content) async {
  final file = File(path);
  final encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(content));
}
