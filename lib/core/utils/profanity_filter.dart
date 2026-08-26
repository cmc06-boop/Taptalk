/// Masks English and Filipino profanity in recognized speech.
///
/// Matches are whole words only, so innocent words that merely contain a
/// blocked stem ("class", "assist", "reputasyon", "putahe", "titik") stay
/// untouched. A masked word keeps its first letter: "puta" → "p***".
class ProfanityFilter {
  ProfanityFilter._();

  /// Regex fragments, longest variants first so boundaries resolve correctly.
  static const List<String> _entries = <String>[
    // Filipino
    r'putang\s*inang?(\s*(mo|nyo|niyo|ninyo))?',
    r'putang\s*ina(\s*(mo|nyo|niyo|ninyo))?',
    r'putangina(mo|nyo|niyo|ninyo)?',
    r'tang\s*ina(\s*(mo|nyo|niyo|ninyo))?',
    r'tangina(mo|nyo|niyo|ninyo)?',
    r'king\s*ina(\s*(mo|nyo|niyo|ninyo))?',
    r'kingina(mo|nyo|niyo|ninyo)?',
    r'puta(ng)?',
    r'putcha',
    r'putsa',
    r'gago(ng|ka)?',
    r'gaga(ng|ka)?',
    r'tanga(ng|ka)?',
    r'bobo(ng|ka)?',
    r'boba(ng|ka)?',
    r'ulol(ka)?',
    r'ungas',
    r'gunggong',
    r'tarantado',
    r'tarantada',
    r'hinayupak',
    r'punyeta(ng|ka)?',
    r'kupal',
    r'bwisit',
    r'buwisit',
    r'lintik',
    r'pakyu',
    r'pakyew',
    r'shet',
    r'syet',
    r'kantot(an|in)?',
    r'kantutan',
    r'kantutin',
    r'iyot(an)?',
    r'jakol',
    r'jakulan',
    r'libog',
    r'malibog',
    r'burat',
    r'pekpek',
    r'puke',
    r'puki',
    r'titi',
    r'tite',
    r'tamod',

    // English
    r'motherfuck(er|ers|ing)?',
    r'fuck(ed|er|ers|ing|in)?',
    r'bullshit',
    r'shit(ty|s|e)?',
    r'bitch(es|ing|y)?',
    r'asshole(s)?',
    r'jackass',
    r'dumbass',
    r'badass',
    r'ass',
    r'arse',
    r'bastard(s)?',
    r'dickhead(s)?',
    r'dick(s)?',
    r'pussy',
    r'cunt(s)?',
    r'whore(s)?',
    r'slut(s|ty)?',
    r'goddamn',
    r'dammit',
    r'damnit',
    r'damn(ed)?',
    r'crap(py)?',
    r'piss(ed|ing)?',
    r'retard(ed|s)?',
    r'faggot(s)?',
    r'nigger(s)?',
    r'nigga(s|h)?',
    r'douche(bag|bags)?',
    r'wanker(s)?',
    r'twat(s)?',
    r'bollocks',
    r'bugger',
  ];

  static final RegExp _pattern = RegExp(
    '\\b(?:${_entries.join('|')})\\b',
    caseSensitive: false,
  );

  /// Returns [input] with every blocked word replaced by its first letter
  /// followed by asterisks.
  static String mask(String input) {
    if (input.isEmpty) return input;
    return input.replaceAllMapped(_pattern, (match) {
      final token = match[0]!;
      return '${token[0]}${'*' * (token.length - 1)}';
    });
  }

  /// Whether [input] contains a blocked word.
  static bool contains(String input) => _pattern.hasMatch(input);
}
