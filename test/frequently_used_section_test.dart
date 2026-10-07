import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/l10n/app_strings.dart';
import 'package:flutter_application_1/core/theme/theme_tokens.dart';
import 'package:flutter_application_1/core/utils/negative_phrases.dart';
import 'package:flutter_application_1/data/models/phrase_usage_stat.dart';
import 'package:flutter_application_1/data/repositories/app_repository.dart';
import 'package:flutter_application_1/services/cloud_notification_backend.dart';
import 'package:flutter_application_1/widgets/frequently_used_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

PhraseUsageStat stat(String text, int count, [String category = 'needs']) =>
    PhraseUsageStat(text: text, categoryKey: category, count: count);

Widget section(
  List<PhraseUsageStat> stats, {
  AppLanguage lang = AppLanguage.english,
  Map<String, int> warningLevels = const {},
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FrequentlyUsedSection(
          stats: stats,
          theme: TapTalkThemes.appDefault,
          lang: lang,
          labelForCategory: (key) => key,
          labelForPhrase: (value) => value.text,
          reloadNonce: 0,
          warningLevels: warningLevels,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (var level = 1; level <= 3; level++) {
    testWidgets('shows warning level $level at ten recorded uses', (
      tester,
    ) async {
      await tester.pumpWidget(
        section([stat('Help', 10)], warningLevels: {'help': level}),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          AppStrings.negativeUsageWarningLevelTitle(AppLanguage.english, level),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'hides the warning below ten uses and updates when level changes',
    (tester) async {
      await tester.pumpWidget(section([stat('Help', 9)]));
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention'), findsNothing);
      await tester.pumpWidget(
        section([stat('Help', 10)], warningLevels: {'help': 1}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention'), findsOneWidget);
      await tester.pumpWidget(
        section([stat('Help', 10)], warningLevels: {'help': 3}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention'), findsNothing);
      expect(find.text('Needs Review'), findsOneWidget);
    },
  );

  testWidgets(
    'See all includes the warning label for phrases outside the preview',
    (tester) async {
      await tester.pumpWidget(
        section(
          [
            for (var i = 0; i < 5; i++) stat('Other $i', 20 - i),
            stat('Help', 10),
          ],
          warningLevels: {'help': 2},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Persistent Pattern'), findsNothing);
      await tester.tap(find.text(AppStrings.seeAll(AppLanguage.english)));
      await tester.pumpAndSettle();
      expect(find.text('Persistent Pattern'), findsOneWidget);
    },
  );

  test(
    'recognizes negative phrases with normalized whitespace, casing and apostrophes',
    () {
      for (final text in [' HELP ', 'Tulong', 'I DON’T   LIKE', 'Galit']) {
        expect(
          NegativePhrases.isNegative(text: text, categoryKey: 'needs'),
          isTrue,
        );
      }
      expect(
        NegativePhrases.isNegative(
          text: 'Chest Pain',
          categoryKey: 'health_safety',
        ),
        isTrue,
      );
      expect(
        NegativePhrases.isNegative(text: 'Happy', categoryKey: 'emotions'),
        isFalse,
      );
    },
  );

  testWidgets('includes five uses, excludes four uses and lesson phrases', (
    tester,
  ) async {
    await tester.pumpWidget(
      section([
        stat('Below threshold', 4),
        stat('At threshold', 5),
        stat('Lesson phrase', 20, 'lesson'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('At threshold'), findsOneWidget);
    expect(find.text('Below threshold'), findsNothing);
    expect(find.text('Lesson phrase'), findsNothing);
    expect(
      find.text(AppStrings.timesUsed(5, AppLanguage.english)),
      findsOneWidget,
    );
  });

  testWidgets(
    'combines language and category counts before filtering or warning',
    (tester) async {
      await tester.pumpWidget(
        section(
          [
            stat('Help', 3, 'needs'),
            stat('Tulong', 3, 'needs'),
            stat('Tulong', 4, 'health_safety'),
          ],
          warningLevels: {'help': 1},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.timesUsed(10, AppLanguage.english)),
        findsOneWidget,
      );
      expect(find.text('Needs Attention'), findsOneWidget);
      await tester.tap(find.text('health_safety'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('needs'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.timesUsed(10, AppLanguage.english)),
        findsOneWidget,
      );
      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Tulong'), findsNothing);
    },
  );

  testWidgets('shows localized empty state below threshold', (tester) async {
    await tester.pumpWidget(
      section([stat('Rare phrase', 4)], lang: AppLanguage.filipino),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.noPhraseUsage(AppLanguage.filipino)),
      findsOneWidget,
    );
    expect(find.text('Rare phrase'), findsNothing);
  });

  testWidgets('sorts phrases by count and can switch category', (tester) async {
    await tester.pumpWidget(
      section([
        stat('Less used', 5),
        stat('Most used', 10),
        stat('Feeling phrase', 7, 'feelings'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Most used')).dy,
      lessThan(tester.getTopLeft(find.text('Less used')).dy),
    );
    await tester.tap(find.text('needs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('feelings'));
    await tester.pumpAndSettle();
    expect(find.text('Feeling phrase'), findsOneWidget);
    expect(find.text('Most used'), findsNothing);
  });

  testWidgets('previews five phrases and See all opens the remaining phrase', (
    tester,
  ) async {
    await tester.pumpWidget(
      section(List.generate(6, (i) => stat('Phrase $i', 10 - i))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phrase 4'), findsOneWidget);
    expect(find.text('Phrase 5'), findsNothing);
    await tester.tap(find.text(AppStrings.seeAll(AppLanguage.english)));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.allFrequentlyUsedTitle(AppLanguage.english)),
      findsOneWidget,
    );
    expect(find.text('Phrase 5'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Phrase 5'), findsNothing);
  });

  testWidgets('refresh replaces a selected category that no longer qualifies', (
    tester,
  ) async {
    await tester.pumpWidget(section([stat('Original phrase', 8)]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section([stat('New phrase', 5, 'feelings')]));
    await tester.pumpAndSettle();
    expect(find.text('New phrase'), findsOneWidget);
    expect(find.text('Original phrase'), findsNothing);
    expect(find.text('feelings'), findsOneWidget);
  });

  test(
    'cloud counts respect period boundaries and exclude lesson/session rows',
    () {
      final start = DateTime(2026, 10, 7);
      final end = start.add(const Duration(days: 1));
      RemoteLearnerActivity activity(
        String text,
        String category,
        DateTime at,
      ) => RemoteLearnerActivity(
        phraseText: text,
        categoryKey: category,
        createdAt: at,
      );
      final result = AppRepository.aggregatePhraseUsageStatsFromActivities(
        activities: [
          activity('Included', 'needs', start),
          activity('Included', 'needs', start.add(const Duration(hours: 1))),
          activity(
            'Too early',
            'needs',
            start.subtract(const Duration(seconds: 1)),
          ),
          activity('Too late', 'needs', end),
          activity('Lesson', 'lesson', start),
          activity(
            AppRepository.appSessionPhraseText,
            AppRepository.appSessionCategoryKey,
            start,
          ),
        ],
        rangeStart: start,
        rangeEnd: end,
      );
      expect(result, hasLength(1));
      expect(result.single.text, 'Included');
      expect(result.single.count, 2);
    },
  );

  test('overlapping local and cloud totals are not added together', () {
    final result = AppRepository.mergePhraseUsageStats(
      [stat('Help', 5)],
      [stat('Help', 7)],
    );
    expect(result, hasLength(1));
    expect(result.single.count, 7);
  });
}
