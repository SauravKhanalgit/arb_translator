import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> translateText(String text, String targetLang) async {
  // Example: Use free Google Translate API via unofficial endpoint
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
