import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/furlo_state.dart';
import 'repositories/notification_settings_repository.dart';
import 'repositories/pet_repository.dart';
import 'screens/home/home_screen.dart';
import 'screens/pets/pet_onboarding_screen.dart';
import 'services/notifications_service.dart';
import 'utils/app_theme.dart';

class FurloApp extends StatefulWidget {
  const FurloApp({
    super.key,
    this.repository,
    this.notificationService,
  });

  final PetRepository? repository;
  final NotificationService? notificationService;

  @override
  State<FurloApp> createState() => _FurloAppState();
}

class _FurloAppState extends State<FurloApp> {
  late final PetRepository _repository =
      widget.repository ?? createPetRepository();
  late final NotificationSettingsRepository _notificationSettings =
      SharedPreferencesNotificationSettingsRepository();
  late final NotificationService _notificationService =
      widget.notificationService ??
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
    return ChangeNotifierProvider(
      create: (_) {
        final state = FurloState(_repository);
        unawaited(state.load());
        return state;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Furlo',
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: AppTheme.dark,
        home: _StartupGate(
          repository: _repository,
          notificationSettings: _notificationSettings,
          notificationService: _notificationService,
        ),
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate({
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
  });

  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FurloState>();
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your pets could not be loaded.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.pets.isNotEmpty) {
      return HomeScreen(
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
      );
    }
    return OnboardingScreen(
      repository: repository,
      notificationSettings: notificationSettings,
      notificationService: notificationService,
    );
  }
}
