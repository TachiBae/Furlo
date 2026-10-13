import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/account_onboarding_repository.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_setup.dart';
import 'utils/app_diagnostics.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthService? authService;
  AccountOnboardingRepository? accountOnboardingRepository;
  String? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    configureFirestore(FirebaseFirestore.instance);
    accountOnboardingRepository = FirestoreAccountOnboardingRepository(
      firestore: FirebaseFirestore.instance,
    );
    authService = FirebaseAuthService(
      accountOnboardingRepository: accountOnboardingRepository,
    );
  } catch (_) {
    logAppDiagnostic('Firebase initialization failed.');
    firebaseInitError = "Furlo can't start right now. Please try again later.";
  }

  // Restore the saved theme before the first frame, so a Light or Dark user
  // never sees the Default palette flash while it loads.
  final themeSettings = ThemeSettings();
  await themeSettings.load();

  runApp(
    DevicePreview(
      // Web is the delivered surface (GitHub Pages): always show the device
      // frame there. Other platforms keep the debug/profile-only default.
      enabled: kIsWeb || !kReleaseMode,
      builder: (context) => FurloApp(
        authService: authService,
        accountOnboardingRepository: accountOnboardingRepository,
        firebaseInitError: firebaseInitError,
        themeSettings: themeSettings,
      ),
    ),
  );
}
