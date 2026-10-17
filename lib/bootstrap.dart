import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/firebase_providers.dart';
import 'firebase_options.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[PlatformDispatcherError] $error');
    }
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);

  final sharedPrefs = await SharedPreferences.getInstance();

  try {
    FirebaseOptions? options;
    if (kIsWeb) {
      options = DefaultFirebaseOptions.web;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          options = DefaultFirebaseOptions.android;
          break;
        case TargetPlatform.iOS:
          options = DefaultFirebaseOptions.ios;
          break;
        default:
          options = DefaultFirebaseOptions.web;
      }
    }
    await Firebase.initializeApp(options: options);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FirebaseInit] Khởi tạo Firebase chưa khả dụng trên nền tảng này: $e');
    }
  }

  const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  if (useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  } else {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Bỏ qua kích hoạt trong môi trường dev: $e');
      }
    }
  }

  final rootWidget = await builder();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: rootWidget,
    ),
  );
}