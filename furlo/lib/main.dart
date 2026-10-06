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
import 'utils/app_diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthService? authService;
  AccountOnboardingRepository? accountOnboardingRepository;
  String? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    accountOnboardingRepository = FirestoreAccountOnboardingRepository(
      firestore: FirebaseFirestore.instance,
    );
    authService = FirebaseAuthService(
      accountOnboardingRepository: accountOnboardingRepository,
    );
  } catch (_) {
    logAppDiagnostic('Firebase initialization failed.');
    firebaseInitError = 'Cloud setup is missing or failed to start.';
  }

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => FurloApp(
        authService: authService,
        accountOnboardingRepository: accountOnboardingRepository,
        firebaseInitError: firebaseInitError,
      ),
    ),
  );
}
