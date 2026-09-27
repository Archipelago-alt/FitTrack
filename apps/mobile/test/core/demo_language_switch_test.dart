import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:fittrack/core/demo/demo_api_adapter.dart';
import 'package:fittrack/core/demo/demo_store.dart';

/// Redirects `getApplicationDocumentsDirectory()` to a scratch directory so
/// the demo store writes somewhere disposable during tests.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Switching language has to change the names already stored on the device, not
/// just the ones written from then on.
///
/// The provider that builds the demo adapter does not rebuild when the locale
/// changes, so anything the adapter captured at construction stays on the old
/// language for the rest of the run. And a meal item keeps a denormalised
/// `food_name` fixed at the moment it was logged, so even a correct write leaves
/// yesterday's meals reading in the language they were logged in.
///
/// These drive the adapter through one live locale that the test flips, exactly
/// as the running app does, and never rebuild it.
void main() {
  late Directory tmp;
  late DemoStore store;
  late Dio dio;
  late String locale;

  const String appleEn = 'Apple';
  const String appleAr = 'تفاح';
  const String appleId = 'c3a99843-7842-4d27-90b7-71f8ba3d7cbe';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('fittrack_lang_switch');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    final ByteData bytes = await rootBundle.load('assets/demo/seed.json');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final String key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/demo/seed.json') return bytes;
      return null;
    });

    store = await DemoStore.open();
    locale = 'en';
    dio = Dio(BaseOptions(
      baseUrl: 'http://demo.local',
      validateStatus: (int? s) => s != null && s < 500,
    ))
      ..httpClientAdapter = DemoApiAdapter(store, localeCode: () => locale);
  });

  tearDown(() async => tmp.delete(recursive: true));

  /// Log a portion of one food, the way the food-search screen does.
  Future<void> logApple() async {
    final Response<dynamic> posted = await dio.post<dynamic>(
      '/api/v1/nutrition/meals',
      data: <String, dynamic>{
        'meal_type': 'snack',
        'items': <dynamic>[
          <String, dynamic>{'food_id': appleId, 'grams': 100},
        ],
      },
    );
    expect(posted.statusCode, anyOf(200, 201));
  }

  /// Every stored item name for today, in whatever language is selected now.
  Future<List<String>> loggedNamesToday() async {
    final Response<dynamic> got =
        await dio.get<dynamic>('/api/v1/nutrition/meals');
    final List<dynamic> meals = got.data as List<dynamic>;
    return <String>[
      for (final dynamic meal in meals)
        for (final dynamic item
            in (meal as Map<String, dynamic>)['items'] as List<dynamic>)
          (item as Map<String, dynamic>)['food_name'] as String,
    ];
  }

  test('a meal logged in English reads in Arabic after the switch', () async {
    await logApple();
    expect(await loggedNamesToday(), contains(appleEn));

    // The same adapter, mid-run: only the selected language changes.
    locale = 'ar';

    final List<String> afterSwitch = await loggedNamesToday();
    expect(afterSwitch, contains(appleAr),
        reason: 'the stored English name was returned unchanged, so a meal '
            'logged before the switch still reads English in Arabic');
    expect(afterSwitch, isNot(contains(appleEn)));
  });

  test('a meal logged in Arabic reads in English after switching back',
      () async {
    locale = 'ar';
    await logApple();
    expect(await loggedNamesToday(), contains(appleAr));

    locale = 'en';
    final List<String> afterSwitch = await loggedNamesToday();
    expect(afterSwitch, contains(appleEn));
    expect(afterSwitch, isNot(contains(appleAr)));
  });

  test('macros and portion survive the name being re-resolved', () async {
    await logApple();
    final Response<dynamic> before =
        await dio.get<dynamic>('/api/v1/nutrition/meals');
    final Map<String, dynamic> itemEn = ((before.data as List<dynamic>).first
        as Map<String, dynamic>)['items'][0] as Map<String, dynamic>;

    locale = 'ar';
    final Response<dynamic> after =
        await dio.get<dynamic>('/api/v1/nutrition/meals');
    final Map<String, dynamic> itemAr = ((after.data as List<dynamic>).first
        as Map<String, dynamic>)['items'][0] as Map<String, dynamic>;

    expect(itemAr['food_name'], isNot(itemEn['food_name']));
    for (final String key in <String>[
      'food_id',
      'grams',
      'calories',
      'protein_g',
      'carbs_g',
      'fat_g',
      'fiber_g',
    ]) {
      expect(itemAr[key], itemEn[key],
          reason: '$key changed with the language');
    }
  });

  test('a generated plan names its exercises in the selected language',
      () async {
    Future<List<String>> planNames() async {
      final Response<dynamic> res = await dio.post<dynamic>(
        '/api/v1/ai/plans/generate',
        data: <String, dynamic>{'days_per_week': 2},
      );
      final Map<String, dynamic> plan =
          (res.data as Map<String, dynamic>)['plan'] as Map<String, dynamic>;
      return <String>[
        for (final dynamic day in plan['days'] as List<dynamic>)
          for (final dynamic e
              in (day as Map<String, dynamic>)['exercises'] as List<dynamic>)
            (e as Map<String, dynamic>)['name'] as String,
      ];
    }

    final List<String> en = await planNames();
    locale = 'ar';
    final List<String> ar = await planNames();

    expect(en, isNotEmpty);
    expect(ar, isNotEmpty);
    final RegExp arabic = RegExp(r'[؀-ۿ]');
    expect(ar.any((String n) => arabic.hasMatch(n)), isTrue,
        reason: 'no Arabic exercise name in a plan generated in Arabic');
    expect(ar, isNot(equals(en)));
  });
}
