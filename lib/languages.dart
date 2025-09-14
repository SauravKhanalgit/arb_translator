/// A set of all supported ISO-639 language codes for translation.
///
/// These codes can be used as the [targetLang] parameter in translation
/// functions like [translateText].
const supportedLangCodes = {
  'af',
  'sq',
  'am',
  'ar',
  'hy',
  'az',
  'eu',
  'be',
  'bn',
  'bs',
  'bg',
  'ca',
  'ceb',
  'ny',
  'zh',
  'zh-cn',
  'zh-tw',
  'co',
  'hr',
  'cs',
  'da',
  'nl',
  'en',
  'eo',
  'et',
  'tl',
  'fi',
  'fr',
  'fy',
  'gl',
  'ka',
  'de',
  'el',
  'gu',
  'ht',
  'ha',
  'haw',
  'he',
  'hi',
  'hmn',
  'hu',
  'is',
  'ig',
  'id',
  'ga',
  'it',
  'ja',
  'jv',
  'kn',
  'kk',
  'km',
  'rw',
  'ko',
  'ku',
  'ky',
  'lo',
  'la',
  'lv',
  'lt',
  'lb',
  'mk',
  'mg',
  'ms',
  'ml',
  'mt',
  'mi',
  'mr',
  'mn',
  'my',
  'ne',
  'no',
  'or',
  'ps',
  'fa',
  'pl',
  'pt',
  'pa',
  'ro',
  'ru',
  'sm',
  'gd',
  'sr',
  'st',
  'sn',
  'sd',
  'si',
  'sk',
  'sl',
  'so',
  'es',
  'su',
  'sw',
  'sv',
  'tg',
  'ta',
  'tt',
  'te',
  'th',
  'tr',
  'tk',
  'uk',
  'ur',
  'ug',
  'uz',
  'vi',
  'cy',
  'xh',
  'yi',
  'yo',
  'zu'
};

/// Validates the given [code] as a supported language code.
///
/// Converts [code] to lowercase and checks if it exists in [supportedLangCodes].
/// If the code is invalid, an [Exception] is thrown with a helpful error message.
///
/// Example:
/// ```dart
/// final lang = validateLangCode('Ne'); // returns 'ne'
/// validateLangCode('xx'); // throws Exception
/// ```
///
/// [code]: The language code to validate (case-insensitive).
///
/// Returns the normalized (lowercase) version of the code if valid.
///
/// Throws [Exception] if the code is not supported.
String validateLangCode(String code) {
  final normalized = code.toLowerCase();
  if (!supportedLangCodes.contains(normalized)) {
    throw Exception("❌ Unsupported language code: '$code'. "
        "Please use a valid ISO-639 code (e.g. 'ne' for Nepali, 'fr' for French).");
  }
  return normalized;
}
