import 'app_strings.dart';

/// Localized display text for seeded categories, phrases, and theme names.
abstract final class ContentLocalization {
  static const Map<String, String> _categoryFil = {
    'feelings': 'Damdamin',
    'food': 'Pagkain',
    'drinks': 'Inumin',
    'activities': 'Mga Gawain',
    'animals': 'Mga Hayop',
  };

  static const Map<String, String> _phraseFil = {
    'I am happy': 'Masaya ako',
    'I feel sad': 'Malungkot ako',
    'I want pizza': 'Gusto ko ng pizza',
    'I want water': 'Gusto ko ng tubig',
    'I want to sleep': 'Gusto kong matulog',
    'I want to see a dog': 'Gusto kong makakita ng aso',
  };

  static const Map<String, String> _themeFil = {
    'calm_blue': 'Kalmadong Asul',
    'soft_purple': 'Lilang Pantay',
    'mint_green': 'Berdeng Paglago',
    'soft_orange': 'Kahel na Lakas',
    'sun_yellow': 'Dilaw na Galak',
    'peach': 'Peach na Pag-aalaga',
    'sky': 'Kalmadong Langit',
    'lavender': 'Kalmadong Lavender',
    'teal': 'Teal na Pokus',
    'light_gray': 'Neutral na Kalmado',
  };

  static const Map<String, String> _roleFil = {
    'learner': 'Mag-aaral',
    'parent': 'Magulang',
    'teacher': 'Guro',
  };

  static String category(
    String categoryKey,
    String storedName,
    AppLanguage lang,
  ) {
    if (lang == AppLanguage.english) return storedName;
    return _categoryFil[categoryKey] ?? storedName;
  }

  static String phrase(
    String storedText,
    String categoryKey, {
    bool isBuiltin = false,
    required AppLanguage lang,
  }) {
    if (lang == AppLanguage.english) return storedText;
    return _phraseFil[storedText] ?? storedText;
  }

  static String themeName(String themeKey, String storedName, AppLanguage lang) {
    if (lang == AppLanguage.english) return storedName;
    return _themeFil[themeKey] ?? storedName;
  }

  static String role(String roleKey, AppLanguage lang) {
    if (lang == AppLanguage.english) {
      switch (roleKey) {
        case 'learner':
          return 'Learner';
        case 'parent':
          return 'Parent';
        case 'teacher':
          return 'Teacher';
        default:
          return roleKey;
      }
    }
    return _roleFil[roleKey] ?? roleKey;
  }
}
