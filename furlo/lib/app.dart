import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'repositories/pet_repository.dart';
import 'repositories/notification_settings_repository.dart';
import 'services/notifications_service.dart';
import 'screens/pets/pet_onboarding_screen.dart';
import 'utils/app_theme.dart';

class FurloApp extends StatefulWidget {
  const FurloApp({super.key});

  @override
  State<FurloApp> createState() => _FurloAppState();
}

class _FurloAppState extends State<FurloApp> {
  late final PetRepository _repository = createPetRepository();
  late final NotificationSettingsRepository _notificationSettings =
      SharedPreferencesNotificationSettingsRepository();
  late final NotificationService _notificationService =
      createNotificationService(
        repository: _repository,
        settings: _notificationSettings,
      );

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _notificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Furlo',
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.dark,
      home: OnboardingScreen(
        repository: _repository,
        notificationSettings: _notificationSettings,
        notificationService: _notificationService,
      ),
    );
  }
}
