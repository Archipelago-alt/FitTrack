import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fittrack/core/localization/app_localizations.dart';
import 'package:fittrack/core/localization/data_labels.dart';
import 'package:fittrack/features/goals/domain/goal.dart';
import 'package:fittrack/features/habits/domain/habit.dart';
import 'package:fittrack/features/nutrition/domain/nutrition_models.dart';
import 'package:fittrack/features/programs/domain/program.dart';
import 'package:fittrack/features/progress/domain/progress_models.dart';
import 'package:fittrack/features/workout/domain/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The data half of the translation work.
///
/// UI copy lives in the ARB files and is guarded by localization_test. The
/// names the user reads most — their programs, days, workouts, habits, goals
/// and serving sizes — arrive from the bundled data instead, so they need
/// their own guard: one for the data carrying an Arabic field at all, and one
/// for the models and labels actually preferring it.
void main() {
  group('bundled data', () {
    late Map<String, dynamic> seed;

    setUpAll(() {
      seed = jsonDecode(File('assets/demo/seed.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    List<Map<String, dynamic>> listOf(dynamic value) {
      if (value is List) {
        return value
            .map((dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
            .toList();
      }
      if (value is Map) {
        for (final String key in <String>['items', 'results', 'data']) {
          if (value[key] is List) return listOf(value[key]);
        }
      }
      return <Map<String, dynamic>>[];
    }

    /// Every [field] present in [rows] also has a non-empty `<field>_ar`.
    void expectArabic(
      String label,
      List<Map<String, dynamic>> rows,
      List<String> fields,
    ) {
      expect(rows, isNotEmpty, reason: '$label: nothing to check');
      final List<String> missing = <String>[];
      for (final Map<String, dynamic> row in rows) {
        for (final String field in fields) {
          final Object? value = row[field];
          if (value is! String || value.isEmpty) continue;
          final Object? arabic = row['${field}_ar'];
          if (arabic is! String || arabic.trim().isEmpty) {
            missing.add('$label.$field: "$value"');
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'bundled data with no Arabic:\n${missing.join('\n')}');
    }

    test('exercise and food names are bilingual', () {
      expectArabic('exercise', listOf(seed['exercises']), <String>['name']);
      expectArabic('food', listOf(seed['foods']), <String>['name']);
    });

    test('programs, their days and their descriptions are bilingual', () {
      final List<Map<String, dynamic>> programs = <Map<String, dynamic>>[
        ...listOf(seed['program_templates']),
        ...listOf(seed['programs']),
        if (seed['active_program'] is Map)
          Map<String, dynamic>.from(
              seed['active_program'] as Map<dynamic, dynamic>),
      ];
      expectArabic('program', programs, <String>['name', 'description']);
      final List<Map<String, dynamic>> days = <Map<String, dynamic>>[
        for (final Map<String, dynamic> program in programs)
          ...listOf(program['days']),
      ];
      expectArabic('day', days, <String>['name']);
    });

    test('workout history, habits and goals are bilingual', () {
      expectArabic(
          'session', listOf(seed['workout_sessions']), <String>['name']);
      expectArabic('habit', listOf(seed['habits']), <String>['name']);
      expectArabic('goal', listOf(seed['goals']), <String>['title']);
    });

    test('serving sizes are bilingual', () {
      final List<Map<String, dynamic>> options = <Map<String, dynamic>>[
        for (final Map<String, dynamic> food in listOf(seed['foods']))
          ...listOf(food['serving_options']),
      ];
      expectArabic('serving', options, <String>['label']);
    });

    test("the dashboard's denormalised names are bilingual", () {
      final Map<String, dynamic> today = Map<String, dynamic>.from(
          (seed['progress_dashboard'] as Map<dynamic, dynamic>)['today_workout']
              as Map<dynamic, dynamic>);
      expectArabic('today', <Map<String, dynamic>>[today],
          <String>['program_name', 'day_name']);
    });
  });

  group('models prefer the Arabic name in Arabic', () {
    test('program, day and session', () {
      final Program program = Program.fromJson(<String, dynamic>{
        'id': 'p1',
        'name': 'Upper / Lower',
        'name_ar': 'علوي / سفلي',
        'description': 'Four sessions a week.',
        'description_ar': 'أربع حصص في الأسبوع.',
        'status': 'active',
        'days_per_week': 4,
        'days': <dynamic>[
          <String, dynamic>{
            'id': 'd1',
            'name': 'Upper A',
            'name_ar': 'علوي أ',
            'position': 0,
          },
        ],
      });
      expect(program.displayName('ar'), 'علوي / سفلي');
      expect(program.displayName('en'), 'Upper / Lower');
      expect(program.displayDescription('ar'), 'أربع حصص في الأسبوع.');
      expect(program.displayDescription('en'), 'Four sessions a week.');
      expect(program.days.single.displayName('ar'), 'علوي أ');
      expect(program.days.single.displayName('en'), 'Upper A');

      final WorkoutSession session = WorkoutSession.fromJson(<String, dynamic>{
        'id': 's1',
        'name': 'Lower B',
        'name_ar': 'سفلي ب',
        'started_at': '2026-09-20T10:00:00Z',
      });
      expect(session.displayName('ar'), 'سفلي ب');
      expect(session.displayName('en'), 'Lower B');
      // The Arabic name survives a round trip, so history keeps it.
      expect(WorkoutSession.fromJson(session.toJson()).displayName('ar'),
          'سفلي ب');
    });

    test('habit, goal, serving option and the dashboard card', () {
      final Habit habit = Habit.fromJson(<String, dynamic>{
        'id': 'h1',
        'name': 'Sleep 7+ hours',
        'name_ar': 'النوم ٧ ساعات أو أكثر',
      });
      expect(habit.displayName('ar'), 'النوم ٧ ساعات أو أكثر');
      expect(habit.displayName('en'), 'Sleep 7+ hours');

      final Goal goal = Goal.fromJson(<String, dynamic>{
        'id': 'g1',
        'title': 'Reach 78 kg',
        'title_ar': 'الوصول إلى ٧٨ كجم',
        'target_value': 78,
        'start_date': '2026-09-01',
      });
      expect(goal.displayTitle('ar'), 'الوصول إلى ٧٨ كجم');
      expect(goal.displayTitle('en'), 'Reach 78 kg');

      final ServingOption option = ServingOption.fromJson(<String, dynamic>{
        'label': '1 slice (40 g)',
        'grams': 40,
        'label_ar': 'شريحة واحدة (٤٠ غ)',
      });
      expect(option.displayLabel('ar'), 'شريحة واحدة (٤٠ غ)');
      expect(option.displayLabel('en'), '1 slice (40 g)');

      final TodayWorkout today = TodayWorkout.fromJson(<String, dynamic>{
        'program_id': 'p1',
        'program_name': 'Upper / Lower — My Plan',
        'program_name_ar': 'علوي / سفلي — خطتي',
        'day_id': 'd1',
        'day_name': 'Upper B',
        'day_name_ar': 'علوي ب',
      });
      expect(today.displayDayName('ar'), 'علوي ب');
      expect(today.displayProgramName('ar'), 'علوي / سفلي — خطتي');
      expect(today.displayDayName('en'), 'Upper B');
    });

    test('a name with no translation falls back rather than showing nothing',
        () {
      // A program the user typed themselves has no Arabic field at all.
      final Program mine = Program.fromJson(<String, dynamic>{
        'id': 'p2',
        'name': 'My own split',
        'status': 'active',
        'days_per_week': 3,
      });
      expect(mine.displayName('ar'), 'My own split');
      expect(mine.displayDescription('ar'), isNull);

      final Habit blank = Habit.fromJson(<String, dynamic>{
        'id': 'h2',
        'name': 'Walk the dog',
        'name_ar': '',
      });
      expect(blank.displayName('ar'), 'Walk the dog');
    });
  });

  group('data labels', () {
    late AppLocalizations en;
    late AppLocalizations ar;

    AppLocalizations load(String code) {
      final Map<String, dynamic> raw =
          jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
              as Map<String, dynamic>;
      return AppLocalizations(
        Locale(code),
        <String, String>{
          for (final String key in raw.keys)
            if (!key.startsWith('@')) key: '${raw[key]}',
        },
      );
    }

    setUpAll(() {
      en = load('en');
      ar = load('ar');
    });

    test('measurement types are translated, not title-cased slugs', () {
      expect(en.measurement('left_thigh'), 'Left thigh');
      expect(ar.measurement('left_thigh'), 'الفخذ الأيسر');
      for (final String type in <String>[
        'waist',
        'chest',
        'hips',
        'neck',
        'shoulders',
        'left_arm',
        'right_arm',
        'right_thigh',
      ]) {
        expect(ar.measurement(type), isNot(en.measurement(type)),
            reason: '$type reads the same in both languages');
      }
      // An unknown type stays readable instead of showing a raw slug.
      expect(ar.measurement('left_forearm'), 'Left Forearm');
    });

    test('units beside a number are translated', () {
      expect(ar.unit('kg'), 'كجم');
      expect(ar.unit('workouts'), 'تمارين');
      expect(en.unit('workouts'), 'workouts');
      expect(ar.unit('cm'), 'سم');
      // Nothing to show, and an unknown unit passed through as given.
      expect(ar.unit(null), '');
      expect(ar.unit('furlongs'), 'furlongs');
    });

    test('chart series use their key, not the English label in the data', () {
      expect(ar.series('body_weight', 'Body weight'), 'وزن الجسم');
      expect(ar.series('volume', 'Training volume'), 'حجم التدريب');
      expect(ar.series('calories', 'Calories'), 'السعرات');
      expect(ar.series('waist', 'Waist'), 'محيط الخصر');
      expect(en.series('frequency', 'Workouts'), 'Workouts');
      // An unknown series keeps whatever label the data carried.
      expect(ar.series('grip_strength', 'Grip strength'), 'Grip strength');
    });

    test('every ARB key the data labels map to exists in both files', () {
      // The maps in data_labels.dart name ARB keys as map values. A typo there
      // would surface as a raw key on someone's screen, which nothing else
      // catches: the usual scan only looks for `.t('key')` call sites.
      final String source =
          File('lib/core/localization/data_labels.dart').readAsStringSync();
      final Set<String> referenced = RegExp(r"'[^']+':\s*'([A-Za-z0-9]+)'")
          .allMatches(source)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
      expect(referenced, isNotEmpty, reason: 'the scan found no ARB keys');
      for (final String key in referenced) {
        expect(en.t(key), isNot(key), reason: 'missing from English: $key');
        expect(ar.t(key), isNot(key), reason: 'missing from Arabic: $key');
      }
    });

    test('a prescription reads in the right language', () {
      expect(en.prescription(sets: 4, repsMin: 6, repsMax: 10), '4 × 6-10');
      expect(ar.prescription(sets: 4, repsMin: 6, repsMax: 10), '4 × 6-10');
      expect(en.prescription(sets: 3, repsMin: 8, repsMax: 8), '3 × 8');
      expect(en.prescription(sets: 3), '3 sets');
      expect(ar.prescription(sets: 3), '3 مجموعات');
      expect(en.prescription(sets: 3, durationSeconds: 45), '3 × 45s');
      expect(ar.prescription(sets: 3, durationSeconds: 45), '3 × 45ث');
    });
  });
}
