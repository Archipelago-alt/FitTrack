import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack/features/exercises/domain/exercise.dart';
import 'package:fittrack/features/nutrition/domain/nutrition_models.dart';

/// Every exercise and food the app ships has to carry an Arabic name, and the
/// models have to pick it.
///
/// The screens call `displayName(languageCode)`, so a missing `name_ar` does not
/// fail loudly — it silently falls back to English for that one row, which is
/// the kind of gap only a reader of Arabic would notice. These read the shipped
/// asset so a data regression is caught here rather than on a phone.
///
/// Programs, program templates, workout sessions and habits carry no `name_ar`
/// at all, so those names read English in both languages. That is a gap in the
/// bundled data rather than in this code, and it is deliberately not asserted
/// here; asserting it would freeze the gap in place.
void main() {
  late Map<String, dynamic> seed;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final String raw = utf8.decode(
      (await rootBundle.load('assets/demo/seed.json')).buffer.asUint8List(),
    );
    seed = jsonDecode(raw) as Map<String, dynamic>;
  });

  List<Map<String, dynamic>> itemsOf(String key) {
    final dynamic node = seed[key];
    final dynamic list = node is Map<String, dynamic> ? node['items'] : node;
    return <Map<String, dynamic>>[
      for (final dynamic e in list as List<dynamic>) e as Map<String, dynamic>,
    ];
  }

  test('every bundled exercise has a non-empty Arabic name', () {
    final List<Map<String, dynamic>> all = itemsOf('exercises');
    expect(all, hasLength(80));
    final List<String> missing = <String>[
      for (final Map<String, dynamic> e in all)
        if ((e['name_ar'] as String?)?.isNotEmpty != true)
          '${e['id']} (${e['name']})',
    ];
    expect(missing, isEmpty, reason: 'exercises with no Arabic name: $missing');
  });

  test('every bundled food has a non-empty Arabic name', () {
    final List<Map<String, dynamic>> all = itemsOf('foods');
    expect(all, hasLength(60));
    final List<String> missing = <String>[
      for (final Map<String, dynamic> f in all)
        if ((f['name_ar'] as String?)?.isNotEmpty != true)
          '${f['id']} (${f['name']})',
    ];
    expect(missing, isEmpty, reason: 'foods with no Arabic name: $missing');
  });

  test('exercise objects nested in records and the active program carry Arabic',
      () {
    final List<String> missing = <String>[];
    void walk(dynamic node, String path) {
      if (node is Map<String, dynamic>) {
        final bool looksLikeExercise =
            node.containsKey('name') && node.containsKey('muscle_group');
        if (looksLikeExercise &&
            (node['name_ar'] as String?)?.isNotEmpty != true) {
          missing.add('$path (${node['name']})');
        }
        node.forEach((String k, dynamic v) => walk(v, '$path.$k'));
      } else if (node is List<dynamic>) {
        for (int i = 0; i < node.length; i++) {
          walk(node[i], '$path[$i]');
        }
      }
    }

    for (final String key in <String>[
      'personal_records',
      'progress_dashboard',
      'active_program',
    ]) {
      walk(seed[key], key);
    }
    expect(missing, isEmpty,
        reason: 'nested exercises with no Arabic name: $missing');
  });

  test('the models resolve a bundled exercise and food in both languages', () {
    final Exercise exercise = Exercise.fromJson(itemsOf('exercises').firstWhere(
      (Map<String, dynamic> e) => (e['name_ar'] as String?)?.isNotEmpty == true,
    ));
    final Food food = Food.fromJson(itemsOf('foods').firstWhere(
      (Map<String, dynamic> f) => (f['name_ar'] as String?)?.isNotEmpty == true,
    ));

    final RegExp arabic = RegExp(r'[؀-ۿ]');
    for (final String name in <String>[
      exercise.displayName('ar'),
      food.displayName('ar'),
    ]) {
      expect(arabic.hasMatch(name), isTrue, reason: '"$name" is not Arabic');
    }
    expect(exercise.displayName('en'), exercise.name);
    expect(food.displayName('en'), food.name);
  });

  test('an empty Arabic name falls back to English rather than showing blank',
      () {
    final Map<String, dynamic> raw =
        Map<String, dynamic>.from(itemsOf('exercises').first)..['name_ar'] = '';
    expect(Exercise.fromJson(raw).displayName('ar'), raw['name']);
  });
}
