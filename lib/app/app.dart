import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/providers/firebase_providers.dart';
import '../core/utils/currency_formatter.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

class ElectronicStoreApp extends ConsumerWidget {
  const ElectronicStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFirebase = Firebase.apps.isNotEmpty;
    bool hasMockOverrides = false;
    try {
      ref.read(firestoreProvider);
      hasMockOverrides = true;
    } catch (_) {
      hasMockOverrides = false;
    }

    if (!hasFirebase && !hasMockOverrides) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('vi', 'VN'),
        home: Scaffold(
          appBar: AppBar(title: const Text(AppConstants.appName)),
          body: Center(
            child: Text(
              'Kiểm tra định dạng VND: ${CurrencyFormatter.formatVnd(3490000)}',
            ),
          ),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [
        Locale('vi', 'VN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
