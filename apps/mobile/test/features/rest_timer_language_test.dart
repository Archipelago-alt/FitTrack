import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack/core/localization/app_localizations.dart';
import 'package:fittrack/features/workout/application/rest_timer_controller.dart';
import 'package:fittrack/features/workout/presentation/widgets/rest_timer_bar.dart';

/// The rest timer names the exercise on screen, so that name has to follow the
/// reader's language like every other exercise name.
///
/// It is resolved in the bar rather than by the controller that starts the
/// timer: that controller has no locale to resolve with, and reaching for one
/// couples it to app preferences the workout tests deliberately do not provide.
/// Both names travel in the timer state and the choice is made here.
Widget _bar(ProviderContainer container, Locale locale) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: RestTimerBar()),
      ),
    );

void main() {
  const String en = 'Bench Press';
  const String ar = 'ضغط البنش';

  Future<ProviderContainer> started(WidgetTester tester, Locale locale) async {
    final ProviderContainer container = ProviderContainer();
    container
        .read(restTimerProvider.notifier)
        .start(90, exerciseName: en, exerciseNameAr: ar);
    await tester.pumpWidget(_bar(container, locale));
    await tester.pump();
    return container;
  }

  testWidgets('names the exercise in Arabic when the app is Arabic',
      (WidgetTester tester) async {
    final ProviderContainer container =
        await started(tester, const Locale('ar'));
    expect(find.text(ar), findsOneWidget);
    expect(find.text(en), findsNothing);
    container.read(restTimerProvider.notifier).skip();
    container.dispose();
  });

  testWidgets('names the exercise in English when the app is English',
      (WidgetTester tester) async {
    final ProviderContainer container =
        await started(tester, const Locale('en'));
    expect(find.text(en), findsOneWidget);
    expect(find.text(ar), findsNothing);
    container.read(restTimerProvider.notifier).skip();
    container.dispose();
  });

  testWidgets('falls back to the English name when there is no Arabic one',
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    container.read(restTimerProvider.notifier).start(90, exerciseName: en);
    await tester.pumpWidget(_bar(container, const Locale('ar')));
    await tester.pump();
    expect(find.text(en), findsOneWidget);
    container.read(restTimerProvider.notifier).skip();
    container.dispose();
  });
}
