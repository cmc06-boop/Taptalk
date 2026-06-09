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

  static const Map<String, String> _categoryEn = {
    'feelings': 'Feelings',
    'food': 'Food',
    'drinks': 'Drinks',
    'activities': 'Activities',
    'animals': 'Animals',
  };

  /// Exact phrase pairs (canonical English -> Filipino).
  static const Map<String, String> _phraseFil = {
    'I am happy': 'Masaya ako',
    'I am hungry': 'Gutom ako',
    'I am thirsty': 'Uhaw ako',
    'I am tired': 'Pagod ako',
    'I am sleepy': 'Inaantok ako',
    'I am sick': 'May sakit ako',
    'I am scared': 'Natatakot ako',
    'I am hot': 'Mainit ako',
    'I am cold': 'Nilalamig ako',
    'I feel sad': 'Malungkot ako',
    'I feel angry': 'Galit ako',
    'I want pizza': 'Gusto ko ng pizza',
    'I want water': 'Gusto ko ng tubig',
    'I want rice': 'Gusto ko ng kanin',
    'I want milk': 'Gusto ko ng gatas',
    'I want to sleep': 'Gusto kong matulog',
    'I want to play': 'Gusto kong maglaro',
    'I want to eat': 'Gusto kong kumain',
    'I want to go home': 'Gusto kong umuwi',
    'I want to see a dog': 'Gusto kong makakita ng aso',
    'I need help': 'Kailangan ko ng tulong',
    'I need the bathroom': 'Kailangan ko ng banyo',
    'Thank you': 'Salamat',
    'Please': 'Pakiusap',
    'Yes': 'Oo',
    'No': 'Hindi',
    'More please': 'Pa nga',
    'Stop': 'Tumigil',
    'Hello': 'Kumusta',
    'Goodbye': 'Paalam',
  };

  /// Word / short-fragment dictionary for pattern-based translation.
  static const Map<String, String> _wordEnFil = {
    'hungry': 'gutom',
    'thirsty': 'uhaw',
    'tired': 'pagod',
    'sleepy': 'antok',
    'happy': 'masaya',
    'sad': 'malungkot',
    'angry': 'galit',
    'scared': 'takot',
    'sick': 'may sakit',
    'hot': 'mainit',
    'cold': 'ginaw',
    'water': 'tubig',
    'pizza': 'pizza',
    'rice': 'kanin',
    'milk': 'gatas',
    'bread': 'tinapay',
    'food': 'pagkain',
    'help': 'tulong',
    'bathroom': 'banyo',
    'home': 'bahay',
    'dog': 'aso',
    'cat': 'pusa',
    'sleep': 'matulog',
    'play': 'maglaro',
    'eat': 'kumain',
    'ugly': 'pangit',
    'pretty': 'maganda',
    'beautiful': 'maganda',
    'kind': 'mabait',
    'bad': 'masama',
    'good': 'mabuti',
    'smart': 'matalino',
    'stupid': 'bobo',
    'nice': 'mabait',
  };

  static const Map<String, String> _phraseFragmentFil = {
    'see a dog': 'makakita ng aso',
    'see a cat': 'makakita ng pusa',
    'go home': 'umuwi',
    'go to the bathroom': 'pumunta sa banyo',
  };

  static const Set<String> _skipWords = {'a', 'an', 'the', 'to', 'my', 'ng'};

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

  static Map<String, String>? _filToEnWords;
  static List<String>? _knownPhrasesCache;

  static List<String> get _knownPhrasesLongestFirst {
    _knownPhrasesCache ??= {
      ..._phraseFil.keys,
      ..._phraseFil.values,
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return _knownPhrasesCache!;
  }

  static Map<String, String> get _filToEn {
    _filToEnWords ??= {
      for (final entry in _wordEnFil.entries)
        entry.value.toLowerCase(): entry.key,
      for (final entry in _phraseFil.entries)
        entry.value.toLowerCase(): entry.key,
      for (final entry in _phraseFragmentFil.entries)
        entry.value.toLowerCase(): entry.key,
    };
    return _filToEnWords!;
  }

  /// Resolves stored phrase text (English or Filipino) to canonical English.
  static String canonicalPhrase(String storedText) {
    final trimmed = storedText.trim();
    if (trimmed.isEmpty) return trimmed;

    final exact = _phraseFilKeyFor(trimmed);
    if (exact != null) return exact;

    for (final entry in _phraseFil.entries) {
      if (entry.value == trimmed) return entry.key;
    }

    final lower = trimmed.toLowerCase();
    for (final entry in _phraseFil.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }

    final fromPattern = _patternToEnglish(trimmed);
    if (fromPattern != null) return fromPattern;

    final wordByWord = _wordByWordToEnglish(trimmed);
    if (wordByWord != null) return wordByWord;

    final normalized = _normalizeEnglishPhrase(trimmed);
    if (normalized != null) {
      final key = _phraseFilKeyFor(normalized);
      if (key != null) return key;
      return normalized;
    }

    return trimmed;
  }

  static String? _phraseFilKeyFor(String text) {
    if (_phraseFil.containsKey(text)) return text;
    final lower = text.trim().toLowerCase();
    for (final key in _phraseFil.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return null;
  }

  static String? _phraseFilValueFor(String canonicalEnglish) {
    final key = _phraseFilKeyFor(canonicalEnglish);
    if (key == null) return null;
    return _phraseFil[key];
  }

  static final RegExp _phraseBoundaryPattern = RegExp(
    r"\b(i am|i feel|i want to|i want|i need|you are|you're|gusto kong|gusto ko ng|kailangan ko ng)\b",
    caseSensitive: false,
  );

  static bool _hasMultiplePhraseParts(String text) {
    return _phraseBoundaryPattern.allMatches(text).length > 1;
  }

  static String? _normalizeEnglishPhrase(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty || _hasMultiplePhraseParts(lower)) return null;

    final iAm = RegExp(r'^i am (.+)$').firstMatch(lower);
    if (iAm != null) return 'I am ${_titleCaseEnglish(iAm.group(1)!)}';

    final iFeel = RegExp(r'^i feel (.+)$').firstMatch(lower);
    if (iFeel != null) return 'I feel ${_titleCaseEnglish(iFeel.group(1)!)}';

    final iWantTo = RegExp(r'^i want to (.+)$').firstMatch(lower);
    if (iWantTo != null) {
      return 'I want to ${_titleCaseEnglish(iWantTo.group(1)!)}';
    }

    final iWant = RegExp(r'^i want (.+)$').firstMatch(lower);
    if (iWant != null) return 'I want ${_titleCaseEnglish(iWant.group(1)!)}';

    final iNeed = RegExp(r'^i need (.+)$').firstMatch(lower);
    if (iNeed != null) return 'I need ${_titleCaseEnglish(iNeed.group(1)!)}';

    final youAre = RegExp(r'^you are (.+)$').firstMatch(lower);
    if (youAre != null) {
      return 'You are ${_titleCaseEnglish(youAre.group(1)!)}';
    }

    final youre = RegExp(r"^you're (.+)$").firstMatch(lower);
    if (youre != null) {
      return 'You are ${_titleCaseEnglish(youre.group(1)!)}';
    }

    return null;
  }

  static String _titleCaseEnglish(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  static String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static bool _isTitleCase(String value) {
    for (final word in value.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final letters = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (letters.isEmpty) continue;
      if (letters[0] != letters[0].toUpperCase()) return false;
      if (letters.length > 1 && letters.substring(1) != letters.substring(1).toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  static String _applySourceCasing(String source, String translated) {
    final sourceLetters = source.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (sourceLetters.isEmpty) return translated;

    if (sourceLetters == sourceLetters.toUpperCase()) {
      return translated.toUpperCase();
    }
    if (sourceLetters == sourceLetters.toLowerCase()) {
      return translated.toLowerCase();
    }
    if (_isTitleCase(source)) {
      return _titleCaseEnglish(translated);
    }
    if (source[0] == source[0].toUpperCase()) {
      return _capitalizeFirst(translated);
    }
    return translated;
  }

  static bool _regionEqualsIgnoreCase(String text, int start, String known) {
    if (start < 0 || start + known.length > text.length) return false;
    return text.substring(start, start + known.length).toLowerCase() ==
        known.toLowerCase();
  }

  static int _unknownRunEnd(String text, int pos) {
    for (var i = pos + 1; i <= text.length; i++) {
      if (i < text.length &&
          _knownPhrasesLongestFirst.any(
            (known) => _regionEqualsIgnoreCase(text, i, known),
          )) {
        return i;
      }
    }
    return text.length;
  }

  static bool _isPhraseChar(String char) {
    return RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(char);
  }

  static String? _resolveEnglishKey(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final exact = _phraseFilKeyFor(trimmed);
    if (exact != null) return exact;

    for (final entry in _phraseFil.entries) {
      if (entry.value == trimmed) return entry.key;
    }

    final lower = trimmed.toLowerCase();
    for (final entry in _phraseFil.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }

    final fromPattern = _patternToEnglish(trimmed);
    if (fromPattern != null) return fromPattern;

    final wordByWord = _wordByWordToEnglish(trimmed);
    if (wordByWord != null) return wordByWord;

    final normalized = _normalizeEnglishPhrase(trimmed);
    if (normalized != null) {
      final key = _phraseFilKeyFor(normalized);
      if (key != null) return key;
      return normalized;
    }

    return null;
  }

  static String? _translateExactToEnglish(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) return null;

    for (final entry in _phraseFil.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) return entry.key;
    }

    final exact = _phraseFilKeyFor(trimmed);
    if (exact != null) return exact;

    final pattern = _patternToEnglish(trimmed);
    if (pattern != null) return _applySourceCasing(segment, pattern);
    return null;
  }

  static String? _translateExactToFilipino(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) return null;

    final key = _phraseFilKeyFor(trimmed) ??
        _normalizeEnglishPhrase(trimmed);
    if (key != null) return _phraseFilValueFor(key);

    return null;
  }

  static String? _translateSegmentToEnglish(String segment) {
    final exact = _translateExactToEnglish(segment);
    if (exact != null) return exact;

    final key = _resolveEnglishKey(segment);
    if (key == null) return null;
    return _applySourceCasing(segment, key);
  }

  static String? _translateSegmentToFilipino(String segment) {
    final exact = _translateExactToFilipino(segment);
    if (exact != null) return exact;

    final patternFil = _patternToFilipino(segment);
    if (patternFil != null) return _applySourceCasing(segment, patternFil);

    final key = _resolveEnglishKey(segment);
    if (key != null) {
      final fil = _phraseFilValueFor(key) ?? _patternToFilipino(key);
      if (fil != null) return _applySourceCasing(segment, fil);
    }

    final wordFil = _wordByWordToFilipino(segment);
    if (wordFil != null) return _applySourceCasing(segment, wordFil);

    return null;
  }

  static String _translateBySegmentation(String text, AppLanguage targetLang) {
    final whole = targetLang == AppLanguage.english
        ? _translateExactToEnglish(text)
        : _translateExactToFilipino(text);
    if (whole != null) return whole;

    final result = StringBuffer();
    var pos = 0;

    while (pos < text.length) {
      if (!_isPhraseChar(text[pos])) {
        result.write(text[pos]);
        pos++;
        continue;
      }

      String? matchedPhrase;
      var matchedLen = 0;
      for (final known in _knownPhrasesLongestFirst) {
        if (_regionEqualsIgnoreCase(text, pos, known)) {
          matchedPhrase = known;
          matchedLen = known.length;
          break;
        }
      }

      if (matchedPhrase != null) {
        final slice = text.substring(pos, pos + matchedLen);
        final translated = targetLang == AppLanguage.english
            ? _translateExactToEnglish(slice) ?? _translateSegmentToEnglish(slice)
            : _translateExactToFilipino(slice) ?? _translateSegmentToFilipino(slice);
        result.write(translated ?? slice);
        pos += matchedLen;
        continue;
      }

      final runEnd = _unknownRunEnd(text, pos);
      final run = text.substring(pos, runEnd);
      final translated = targetLang == AppLanguage.english
          ? _translateSegmentToEnglish(run)
          : _translateSegmentToFilipino(run);
      result.write(translated ?? run);
      pos = runEnd;
    }

    return result.toString();
  }

  static String _translateText(String storedText, AppLanguage lang) {
    final trimmed = storedText.trim();
    if (trimmed.isEmpty) return storedText;

    if (_isTextInLanguage(trimmed, lang)) return trimmed;

    final lower = trimmed.toLowerCase();
    if (!trimmed.contains(' ')) {
      if (lang == AppLanguage.filipino && _wordEnFil.containsKey(lower)) {
        return _applySourceCasing(trimmed, _wordEnFil[lower]!);
      }
      if (lang == AppLanguage.english && _filToEn.containsKey(lower)) {
        return _applySourceCasing(trimmed, _filToEn[lower]!);
      }
    }

    if (lang == AppLanguage.filipino) {
      final patternFil = _patternToFilipino(trimmed);
      if (patternFil != null) {
        return _applySourceCasing(trimmed, patternFil);
      }
      final exactFil = _translateExactToFilipino(trimmed);
      if (exactFil != null) return _applySourceCasing(trimmed, exactFil);
    } else {
      final patternEn = _patternToEnglish(trimmed);
      if (patternEn != null) {
        return _applySourceCasing(trimmed, patternEn);
      }
      final exactEn = _translateExactToEnglish(trimmed);
      if (exactEn != null) return _applySourceCasing(trimmed, exactEn);
    }

    final translated = _translateBySegmentation(trimmed, lang);
    if (translated != trimmed) return translated;
    return trimmed;
  }

  static bool _isTextInLanguage(String text, AppLanguage lang) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    if (lang == AppLanguage.filipino) {
      for (final entry in _phraseFil.entries) {
        if (entry.value.toLowerCase() == lower) return true;
      }
      if (!_hasMultiplePhraseParts(trimmed) && _patternToEnglish(trimmed) != null) {
        return true;
      }
      return false;
    }

    for (final key in _phraseFil.keys) {
      if (key.toLowerCase() == lower) return true;
    }
    if (_normalizeEnglishPhrase(trimmed) != null) return true;
    if (!trimmed.contains(' ') && _wordEnFil.containsKey(lower)) return true;
    return false;
  }

  static String? _translateFragment(String fragment) {
    final lower = fragment.trim().toLowerCase();
    if (lower.isEmpty) return null;

    if (_wordEnFil.containsKey(lower)) return _wordEnFil[lower];
    if (_phraseFragmentFil.containsKey(lower)) return _phraseFragmentFil[lower];

    final words = lower.split(RegExp(r'\s+'));
    final translated = <String>[];
    var anyTranslated = false;
    for (final word in words) {
      if (_skipWords.contains(word)) {
        translated.add(word);
        continue;
      }
      final fil = _wordEnFil[word];
      if (fil != null) {
        translated.add(fil);
        anyTranslated = true;
      } else {
        translated.add(word);
      }
    }
    return anyTranslated ? translated.join(' ') : null;
  }

  static String? _patternToFilipino(String english) {
    final lower = english.trim().toLowerCase();
    if (lower.isEmpty || _hasMultiplePhraseParts(lower)) return null;

    final iAm = RegExp(r'^i am (.+)$').firstMatch(lower);
    if (iAm != null) {
      final fil = _translateFragment(iAm.group(1)!);
      if (fil != null) return '${_capitalizeFirst(fil)} ako';
    }

    final iFeel = RegExp(r'^i feel (.+)$').firstMatch(lower);
    if (iFeel != null) {
      final fil = _translateFragment(iFeel.group(1)!);
      if (fil != null) return '${_capitalizeFirst(fil)} ako';
    }

    final iWantTo = RegExp(r'^i want to (.+)$').firstMatch(lower);
    if (iWantTo != null) {
      final fil = _translateFragment(iWantTo.group(1)!);
      if (fil != null) return 'Gusto kong $fil';
    }

    final iWant = RegExp(r'^i want (.+)$').firstMatch(lower);
    if (iWant != null) {
      final fil = _translateFragment(iWant.group(1)!);
      if (fil != null) return 'Gusto ko ng $fil';
    }

    final iNeed = RegExp(r'^i need (.+)$').firstMatch(lower);
    if (iNeed != null) {
      final fil = _translateFragment(iNeed.group(1)!);
      if (fil != null) return 'Kailangan ko ng $fil';
    }

    final youAre = RegExp(r'^you are (.+)$').firstMatch(lower);
    if (youAre != null) {
      final fil = _translateFragment(youAre.group(1)!);
      if (fil != null) return '${_capitalizeFirst(fil)} ka';
    }

    final youre = RegExp(r"^you're (.+)$").firstMatch(lower);
    if (youre != null) {
      final fil = _translateFragment(youre.group(1)!);
      if (fil != null) return '${_capitalizeFirst(fil)} ka';
    }

    return null;
  }

  static String? _patternToEnglish(String filipino) {
    final lower = filipino.trim().toLowerCase();
    if (lower.isEmpty || _hasMultiplePhraseParts(lower)) return null;

    final fromMap = _filToEn[lower];
    if (fromMap != null) return fromMap;

    final ako = RegExp(r'^(.+) ako$').firstMatch(lower);
    if (ako != null) {
      final enWord = _reverseWord(ako.group(1)!);
      if (enWord != null) return 'I am ${_titleCaseEnglish(enWord)}';
    }

    final gustoKong = RegExp(r'^gusto kong (.+)$').firstMatch(lower);
    if (gustoKong != null) {
      final enTail = _reverseFragment(gustoKong.group(1)!);
      if (enTail != null) return 'I want to ${_titleCaseEnglish(enTail)}';
    }

    final gustoNg = RegExp(r'^gusto ko ng (.+)$').firstMatch(lower);
    if (gustoNg != null) {
      final enTail = _reverseFragment(gustoNg.group(1)!);
      if (enTail != null) return 'I want ${_titleCaseEnglish(enTail)}';
    }

    final kailangan = RegExp(r'^kailangan ko ng (.+)$').firstMatch(lower);
    if (kailangan != null) {
      final enTail = _reverseFragment(kailangan.group(1)!);
      if (enTail != null) return 'I need ${_titleCaseEnglish(enTail)}';
    }

    final kaPattern = RegExp(r'^(.+) ka$').firstMatch(lower);
    if (kaPattern != null) {
      final enTail = _reverseFragment(kaPattern.group(1)!);
      if (enTail != null) return 'You are $enTail';
    }

    return null;
  }

  static String? _reverseWord(String filWord) {
    final lower = filWord.trim().toLowerCase();
    for (final entry in _wordEnFil.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    return null;
  }

  static String? _wordByWordToEnglish(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;

    final reversed = <String>[];
    var anyReversed = false;
    for (final word in words) {
      if (_skipWords.contains(word.toLowerCase())) {
        reversed.add(word);
        continue;
      }
      final en = _reverseWord(word) ?? _filToEn[word.toLowerCase()];
      if (en != null) {
        reversed.add(en);
        anyReversed = true;
      } else {
        reversed.add(word);
      }
    }
    return anyReversed ? _titleCaseEnglish(reversed.join(' ')) : null;
  }

  static String? _wordByWordToFilipino(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;

    final translated = <String>[];
    var anyTranslated = false;
    for (final word in words) {
      if (_skipWords.contains(word.toLowerCase())) {
        translated.add(word);
        continue;
      }
      final fil = _wordEnFil[word.toLowerCase()];
      if (fil != null) {
        translated.add(fil);
        anyTranslated = true;
      } else {
        translated.add(word);
      }
    }
    return anyTranslated ? translated.join(' ') : null;
  }

  static String? _reverseFragment(String fragment) {
    final lower = fragment.trim().toLowerCase();
    for (final entry in _phraseFragmentFil.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    final words = lower.split(RegExp(r'\s+'));
    final reversed = <String>[];
    var anyReversed = false;
    for (final word in words) {
      if (_skipWords.contains(word)) {
        reversed.add(word);
        continue;
      }
      final en = _reverseWord(word);
      if (en != null) {
        reversed.add(en);
        anyReversed = true;
      } else {
        reversed.add(word);
      }
    }
    return anyReversed ? reversed.join(' ') : null;
  }

  static String _normalizeCategoryToken(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String? _categoryFilForKey(String categoryKey) {
    final trimmed = categoryKey.trim();
    if (trimmed.isEmpty) return null;

    final direct = _categoryFil[trimmed];
    if (direct != null) return direct;

    final normalized = _normalizeCategoryToken(trimmed);
    if (normalized.isNotEmpty) {
      final fromNorm = _categoryFil[normalized];
      if (fromNorm != null) return fromNorm;
    }

    final lower = trimmed.toLowerCase();
    for (final entry in _categoryFil.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
      if (entry.value.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  static String? _categoryEnForKey(String categoryKey) {
    final trimmed = categoryKey.trim();
    if (trimmed.isEmpty) return null;

    final direct = _categoryEn[trimmed];
    if (direct != null) return direct;

    final normalized = _normalizeCategoryToken(trimmed);
    if (normalized.isNotEmpty) {
      final fromNorm = _categoryEn[normalized];
      if (fromNorm != null) return fromNorm;
    }

    final lower = trimmed.toLowerCase();
    for (final entry in _categoryEn.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
      if (entry.value.toLowerCase() == lower) return entry.value;
    }
    for (final entry in _categoryFil.entries) {
      if (entry.value.toLowerCase() == lower) {
        return _categoryEn[entry.key];
      }
    }
    return null;
  }

  static String category(
    String categoryKey,
    String storedName,
    AppLanguage lang,
  ) {
    if (lang == AppLanguage.filipino) {
      return _categoryFilForKey(categoryKey) ??
          _categoryFilForKey(storedName) ??
          storedName;
    }
    return _categoryEnForKey(categoryKey) ??
        _categoryEnForKey(storedName) ??
        storedName;
  }

  /// Phrases are shown and spoken exactly as stored (no auto-translation).
  static String phrase(
    String storedText,
    String categoryKey, {
    bool isBuiltin = false,
    required AppLanguage lang,
  }) {
    return storedText;
  }

  /// Class names, lesson titles, and other user content — stored text only.
  static String freeText(String storedText, AppLanguage lang) => storedText;

  static String themeName(String themeKey, String storedName, AppLanguage lang) {
    if (lang == AppLanguage.filipino) {
      return _themeFil[themeKey] ?? _translateText(storedName, lang);
    }
    final fil = _themeFil[themeKey];
    if (fil != null && fil.toLowerCase() == storedName.trim().toLowerCase()) {
      return storedName;
    }
    return _translateText(storedName, lang);
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
