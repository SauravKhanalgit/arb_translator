import 'dart:convert';
import 'package:http/http.dart' as http;

/// Translates the given [text] into the specified [targetLang].
///
/// This function uses a free unofficial Google Translate API endpoint to
/// perform the translation.
///
/// Example:
/// ```dart
/// final translated = await translateText('Hello', 'es');
/// print(translated); // Hola
/// ```
///
/// [text]: The string to translate.
/// [targetLang]: The target language code (e.g., 'es' for Spanish, 'fr' for French).
///
/// Returns a [Future<String>] containing the translated text.
///
/// Throws an [Exception] if the translation request fails.
Future<String> translateText(String text, String targetLang) async {
  final url = Uri.parse(
    'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final result = json.decode(response.body);
    return result[0][0][0]; // Extract translated text
  } else {
    throw Exception('Translation failed');
  }
}
