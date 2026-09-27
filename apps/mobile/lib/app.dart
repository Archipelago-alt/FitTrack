import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/units.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/sync/application/sync_controller.dart';
import 'features/workout/application/rest_timer_controller.dart';

/// Root widget.
///
/// Also owns the two app-wide lifecycle concerns: draining the offline outbox
/// when the app resumes, and re-syncing the rest timer against the wall clock
/// after the OS has frozen it in the background.
class FitTrackApp extends ConsumerStatefulWidget {
  const FitTrackApp({super.key});

  @override
  ConsumerState<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends ConsumerState<FitTrackApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(restTimerProvider.notifier).resync();
      ref.read(syncProvider.notifier).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final Locale? locale = ref.watch(localeProvider);

    // A rejected refresh token signs the user out from wherever they are.
    ref.listen<int>(sessionExpiredTickProvider, (int? previous, int next) {
      if (previous != null && next > previous) {
        ref.read(authControllerProvider.notifier).handleSessionExpired();
      }
    });

    return MaterialApp.router(
      title: 'FitTrack',
      debugShowCheckedModeBanner: Env.verboseLogging,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // The unit words the formatters print come from the resolved locale,
        // which is only known here — `locale` above may be null, meaning
        // "follow the device".
        Units.labels = _unitLabels(AppLocalizations.of(context));

        // Cap text scaling so a large accessibility setting enlarges type
        // without breaking the set-logging grid.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// The unit words for the active locale, read from the ARB files so the
/// translations live in one place.
UnitLabels _unitLabels(AppLocalizations l10n) => UnitLabels(
      kg: l10n.t('commonKg'),
      lb: l10n.t('unitLb'),
      cm: l10n.t('unitCm'),
      inch: l10n.t('unitIn'),
      km: l10n.t('unitKm'),
      metre: l10n.t('unitMetre'),
      mile: l10n.t('unitMile'),
      foot: l10n.t('unitFoot'),
      hour: l10n.t('unitHourShort'),
      minute: l10n.t('unitMinuteShort'),
    );
