import 'src/exceptions/translation_exceptions.dart';

/// Language information and validation for ARB translation.
///
/// This library provides comprehensive language support with detailed
/// information about each supported language including native names,
/// regions, and validation utilities.

/// Represents a language with its metadata.
class LanguageInfo {
  /// Creates a [LanguageInfo] with the given parameters.
  const LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    this.region,
    this.isRightToLeft = false,
  });

  /// ISO-639 language code (e.g., 'en', 'fr').
  final String code;

  /// English name of the language.
  final String name;

  /// Native name of the language.
  final String nativeName;

  /// Primary region where the language is spoken.
  final String? region;

  /// Whether the language is written from right to left.
  final bool isRightToLeft;

  @override
  String toString() => '$name ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageInfo &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Comprehensive list of supported languages with detailed information.
const Map<String, LanguageInfo> supportedLanguages = {
  'af': LanguageInfo(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans'),
  'sq': LanguageInfo(code: 'sq', name: 'Albanian', nativeName: 'Shqip'),
  'am': LanguageInfo(code: 'am', name: 'Amharic', nativeName: 'አማርኛ'),
  'ar': LanguageInfo(
      code: 'ar', name: 'Arabic', nativeName: 'العربية', isRightToLeft: true),
  'hy': LanguageInfo(code: 'hy', name: 'Armenian', nativeName: 'Հայերեն'),
  'az': LanguageInfo(code: 'az', name: 'Azerbaijani', nativeName: 'Azərbaycan'),
  'eu': LanguageInfo(code: 'eu', name: 'Basque', nativeName: 'Euskera'),
  'be': LanguageInfo(code: 'be', name: 'Belarusian', nativeName: 'Беларуская'),
  'bn': LanguageInfo(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
  'bs': LanguageInfo(code: 'bs', name: 'Bosnian', nativeName: 'Bosanski'),
  'bg': LanguageInfo(code: 'bg', name: 'Bulgarian', nativeName: 'Български'),
  'ca': LanguageInfo(code: 'ca', name: 'Catalan', nativeName: 'Català'),
  'ceb': LanguageInfo(code: 'ceb', name: 'Cebuano', nativeName: 'Cebuano'),
  'ny': LanguageInfo(code: 'ny', name: 'Chichewa', nativeName: 'Chichewa'),
  'zh': LanguageInfo(code: 'zh', name: 'Chinese', nativeName: '中文'),
  'zh-cn': LanguageInfo(
      code: 'zh-cn', name: 'Chinese (Simplified)', nativeName: '简体中文'),
  'zh-tw': LanguageInfo(
      code: 'zh-tw', name: 'Chinese (Traditional)', nativeName: '繁體中文'),
  'co': LanguageInfo(code: 'co', name: 'Corsican', nativeName: 'Corsu'),
  'hr': LanguageInfo(code: 'hr', name: 'Croatian', nativeName: 'Hrvatski'),
  'cs': LanguageInfo(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
  'da': LanguageInfo(code: 'da', name: 'Danish', nativeName: 'Dansk'),
  'nl': LanguageInfo(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
  'en': LanguageInfo(code: 'en', name: 'English', nativeName: 'English'),
  'eo': LanguageInfo(code: 'eo', name: 'Esperanto', nativeName: 'Esperanto'),
  'et': LanguageInfo(code: 'et', name: 'Estonian', nativeName: 'Eesti'),
  'tl': LanguageInfo(code: 'tl', name: 'Filipino', nativeName: 'Filipino'),
  'fi': LanguageInfo(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
  'fr': LanguageInfo(code: 'fr', name: 'French', nativeName: 'Français'),
  'fy': LanguageInfo(code: 'fy', name: 'Frisian', nativeName: 'Frysk'),
  'gl': LanguageInfo(code: 'gl', name: 'Galician', nativeName: 'Galego'),
  'ka': LanguageInfo(code: 'ka', name: 'Georgian', nativeName: 'ქართული'),
  'de': LanguageInfo(code: 'de', name: 'German', nativeName: 'Deutsch'),
  'el': LanguageInfo(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
  'gu': LanguageInfo(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  'ht': LanguageInfo(
      code: 'ht', name: 'Haitian Creole', nativeName: 'Kreyòl ayisyen'),
  'ha': LanguageInfo(code: 'ha', name: 'Hausa', nativeName: 'Harshen Hausa'),
  'haw':
      LanguageInfo(code: 'haw', name: 'Hawaiian', nativeName: 'Ōlelo Hawaiʻi'),
  'he': LanguageInfo(
      code: 'he', name: 'Hebrew', nativeName: 'עברית', isRightToLeft: true),
  'hi': LanguageInfo(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  'hmn': LanguageInfo(code: 'hmn', name: 'Hmong', nativeName: 'Hmong'),
  'hu': LanguageInfo(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
  'is': LanguageInfo(code: 'is', name: 'Icelandic', nativeName: 'Íslenska'),
  'ig': LanguageInfo(code: 'ig', name: 'Igbo', nativeName: 'Igbo'),
  'id': LanguageInfo(
      code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
  'ga': LanguageInfo(code: 'ga', name: 'Irish', nativeName: 'Gaeilge'),
  'it': LanguageInfo(code: 'it', name: 'Italian', nativeName: 'Italiano'),
  'ja': LanguageInfo(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  'jv': LanguageInfo(code: 'jv', name: 'Javanese', nativeName: 'Basa Jawa'),
  'kn': LanguageInfo(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  'kk': LanguageInfo(code: 'kk', name: 'Kazakh', nativeName: 'Қазақ тілі'),
  'km': LanguageInfo(code: 'km', name: 'Khmer', nativeName: 'ភាសាខ្មែរ'),
  'rw':
      LanguageInfo(code: 'rw', name: 'Kinyarwanda', nativeName: 'Ikinyarwanda'),
  'ko': LanguageInfo(code: 'ko', name: 'Korean', nativeName: '한국어'),
  'ku': LanguageInfo(code: 'ku', name: 'Kurdish', nativeName: 'Kurdî'),
  'ky': LanguageInfo(code: 'ky', name: 'Kyrgyz', nativeName: 'Кыргызча'),
  'lo': LanguageInfo(code: 'lo', name: 'Lao', nativeName: 'ພາສາລາວ'),
  'la': LanguageInfo(code: 'la', name: 'Latin', nativeName: 'Latinum'),
  'lv': LanguageInfo(code: 'lv', name: 'Latvian', nativeName: 'Latviešu'),
  'lt': LanguageInfo(code: 'lt', name: 'Lithuanian', nativeName: 'Lietuvių'),
  'lb': LanguageInfo(
      code: 'lb', name: 'Luxembourgish', nativeName: 'Lëtzebuergesch'),
  'mk': LanguageInfo(code: 'mk', name: 'Macedonian', nativeName: 'Македонски'),
  'mg': LanguageInfo(code: 'mg', name: 'Malagasy', nativeName: 'Malagasy'),
  'ms': LanguageInfo(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
  'ml': LanguageInfo(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  'mt': LanguageInfo(code: 'mt', name: 'Maltese', nativeName: 'Malti'),
  'mi': LanguageInfo(code: 'mi', name: 'Maori', nativeName: 'Te Reo Māori'),
  'mr': LanguageInfo(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  'mn': LanguageInfo(code: 'mn', name: 'Mongolian', nativeName: 'Монгол'),
  'my':
      LanguageInfo(code: 'my', name: 'Myanmar (Burmese)', nativeName: 'ဗမာစာ'),
  'ne': LanguageInfo(code: 'ne', name: 'Nepali', nativeName: 'नेपाली'),
  'no': LanguageInfo(code: 'no', name: 'Norwegian', nativeName: 'Norsk'),
  'or': LanguageInfo(code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ'),
  'ps': LanguageInfo(
      code: 'ps', name: 'Pashto', nativeName: 'پښتو', isRightToLeft: true),
  'fa': LanguageInfo(
      code: 'fa', name: 'Persian', nativeName: 'فارسی', isRightToLeft: true),
  'pl': LanguageInfo(code: 'pl', name: 'Polish', nativeName: 'Polski'),
  'pt': LanguageInfo(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
  'pa': LanguageInfo(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  'ro': LanguageInfo(code: 'ro', name: 'Romanian', nativeName: 'Română'),
  'ru': LanguageInfo(code: 'ru', name: 'Russian', nativeName: 'Русский'),
  'sm': LanguageInfo(code: 'sm', name: 'Samoan', nativeName: 'Gagana Samoa'),
  'gd': LanguageInfo(code: 'gd', name: 'Scots Gaelic', nativeName: 'Gàidhlig'),
  'sr': LanguageInfo(code: 'sr', name: 'Serbian', nativeName: 'Српски'),
  'st': LanguageInfo(code: 'st', name: 'Sesotho', nativeName: 'Sesotho'),
  'sn': LanguageInfo(code: 'sn', name: 'Shona', nativeName: 'ChiShona'),
  'sd': LanguageInfo(code: 'sd', name: 'Sindhi', nativeName: 'سنڌي'),
  'si': LanguageInfo(code: 'si', name: 'Sinhala', nativeName: 'සිංහල'),
  'sk': LanguageInfo(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina'),
  'sl': LanguageInfo(code: 'sl', name: 'Slovenian', nativeName: 'Slovenščina'),
  'so': LanguageInfo(code: 'so', name: 'Somali', nativeName: 'Soomaali'),
  'es': LanguageInfo(code: 'es', name: 'Spanish', nativeName: 'Español'),
  'su': LanguageInfo(code: 'su', name: 'Sundanese', nativeName: 'Basa Sunda'),
  'sw': LanguageInfo(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
  'sv': LanguageInfo(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
  'tg': LanguageInfo(code: 'tg', name: 'Tajik', nativeName: 'Тоҷикӣ'),
  'ta': LanguageInfo(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  'tt': LanguageInfo(code: 'tt', name: 'Tatar', nativeName: 'Татарча'),
  'te': LanguageInfo(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  'th': LanguageInfo(code: 'th', name: 'Thai', nativeName: 'ไทย'),
  'tr': LanguageInfo(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
  'tk': LanguageInfo(code: 'tk', name: 'Turkmen', nativeName: 'Türkmen'),
  'uk': LanguageInfo(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
  'ur': LanguageInfo(
      code: 'ur', name: 'Urdu', nativeName: 'اردو', isRightToLeft: true),
  'ug': LanguageInfo(
      code: 'ug', name: 'Uyghur', nativeName: 'ئۇيغۇرچە', isRightToLeft: true),
  'uz': LanguageInfo(code: 'uz', name: 'Uzbek', nativeName: 'Oʻzbek'),
  'vi': LanguageInfo(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
  'cy': LanguageInfo(code: 'cy', name: 'Welsh', nativeName: 'Cymraeg'),
  'xh': LanguageInfo(code: 'xh', name: 'Xhosa', nativeName: 'isiXhosa'),
  'yi': LanguageInfo(
      code: 'yi', name: 'Yiddish', nativeName: 'ייִדיש', isRightToLeft: true),
  'yo': LanguageInfo(code: 'yo', name: 'Yoruba', nativeName: 'Yorùbá'),
  'zu': LanguageInfo(code: 'zu', name: 'Zulu', nativeName: 'isiZulu'),
};

/// A set of all supported ISO-639 language codes for translation.
///
/// These codes can be used as the [targetLang] parameter in translation functions.
Set<String> get supportedLangCodes => supportedLanguages.keys.toSet();

/// Gets language information for the given [code].
///
/// Returns null if the language code is not supported.
///
/// Example:
/// ```dart
/// final info = getLanguageInfo('fr');
/// print(info?.nativeName); // Français
/// ```
LanguageInfo? getLanguageInfo(String code) {
  return supportedLanguages[code.toLowerCase()];
}

/// Gets a list of popular language codes commonly used in mobile apps.
///
/// This is a curated list of the most frequently requested languages
/// for internationalization.
List<String> get popularLanguageCodes => [
      'en', // English
      'es', // Spanish
      'fr', // French
      'de', // German
      'it', // Italian
      'pt', // Portuguese
      'ru', // Russian
      'ja', // Japanese
      'ko', // Korean
      'zh', // Chinese
      'ar', // Arabic
      'hi', // Hindi
      'nl', // Dutch
      'sv', // Swedish
      'da', // Danish
      'no', // Norwegian
      'fi', // Finnish
      'pl', // Polish
      'tr', // Turkish
    ];

/// Gets languages that use right-to-left writing systems.
List<String> get rightToLeftLanguages => supportedLanguages.values
    .where((lang) => lang.isRightToLeft)
    .map((lang) => lang.code)
    .toList();

/// Validates the given [code] as a supported language code.
///
/// Converts [code] to lowercase and checks if it exists in [supportedLangCodes].
/// If the code is invalid, throws [UnsupportedLanguageException].
///
/// Example:
/// ```dart
/// final lang = validateLangCode('Ne'); // returns 'ne'
/// validateLangCode('xx'); // throws UnsupportedLanguageException
/// ```
///
/// [code]: The language code to validate (case-insensitive).
///
/// Returns the normalized (lowercase) version of the code if valid.
///
/// Throws [UnsupportedLanguageException] if the code is not supported.
String validateLangCode(String code) {
  final normalized = code.toLowerCase();
  if (!supportedLangCodes.contains(normalized)) {
    throw UnsupportedLanguageException(code);
  }
  return normalized;
}

/// Suggests similar language codes if the given [code] is not found.
///
/// Uses fuzzy matching to find potentially intended language codes.
///
/// Example:
/// ```dart
/// final suggestions = suggestLanguageCodes('fre'); // ['fr']
/// ```
List<String> suggestLanguageCodes(String code) {
  final normalized = code.toLowerCase();
  final suggestions = <String>[];

  // Exact substring matches
  for (final lang in supportedLanguages.values) {
    if (lang.code.contains(normalized) ||
        lang.name.toLowerCase().contains(normalized) ||
        lang.nativeName.toLowerCase().contains(normalized)) {
      suggestions.add(lang.code);
    }
  }

  // If no suggestions found, try partial matches
  if (suggestions.isEmpty && normalized.length >= 2) {
    final prefix = normalized.substring(0, 2);
    for (final lang in supportedLanguages.values) {
      if (lang.code.startsWith(prefix)) {
        suggestions.add(lang.code);
      }
    }
  }

  return suggestions.take(5).toList(); // Limit to top 5 suggestions
}

/// Formats a list of language codes with their native names.
///
/// Useful for displaying language options to users.
///
/// Example:
/// ```dart
/// final formatted = formatLanguageList(['en', 'fr', 'de']);
/// // Returns: ['English (en)', 'Français (fr)', 'Deutsch (de)']
/// ```
List<String> formatLanguageList(List<String> codes) {
  return codes.map((code) {
    final info = getLanguageInfo(code);
    if (info != null) {
      return '${info.nativeName} (${info.code})';
    } else {
      return code;
    }
  }).toList();
}
