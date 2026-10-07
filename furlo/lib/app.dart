import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/furlo_state.dart';
import 'repositories/notification_settings_repository.dart';
import 'repositories/pet_repository.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pets/pet_onboarding_screen.dart';
import 'services/account_onboarding_repository.dart';
import 'services/auth_service.dart';
import 'services/legacy_local_migration.dart';
import 'services/notifications_service.dart';
import 'utils/app_diagnostics.dart';
import 'utils/app_theme.dart';

class FurloApp extends StatefulWidget {
  const FurloApp({
    super.key,
    this.repository,
    this.notificationService,
    this.authService,
    this.accountOnboardingRepository,
    this.firebaseInitError,
    this.repositoryFactory,
  });

  final PetRepository? repository;
  final NotificationService? notificationService;
  final AuthService? authService;
  final AccountOnboardingRepository? accountOnboardingRepository;
  final String? firebaseInitError;
  final PetRepository Function(String storageScope)? repositoryFactory;

  @override
  State<FurloApp> createState() => _FurloAppState();
}

class _FurloAppState extends State<FurloApp> {
  late final ThemeSettings _themeSettings = ThemeSettings();
  late final Future<void> _themeLoad;
  FurloState? _furloState;

  void _handleFurloState(FurloState? state) {
    if (!mounted) return;
    setState(() => _furloState = state);
  }

  @override
  void initState() {
    super.initState();
    _themeLoad = _themeSettings.load();
  }

  @override
  void dispose() {
    _themeSettings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<AuthService?>.value(value: widget.authService),
      ChangeNotifierProvider<ThemeSettings>.value(value: _themeSettings),
    ],
    child: FutureBuilder<void>(
      future: _themeLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: AppPalette.defaultTheme.bg,
            child: Center(
              child: CircularProgressIndicator(
                color: AppPalette.defaultTheme.textPrimary,
              ),
            ),
          );
        }
        return Consumer<ThemeSettings>(
          builder: (context, themeSettings, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Furlo',
            locale: DevicePreview.locale(context),
            builder: (context, child) {
              final furloState = _furloState;
              final content = child ?? const SizedBox.shrink();
              return DevicePreview.appBuilder(
                context,
                furloState == null
                    ? content
                    : ChangeNotifierProvider<FurloState>.value(
                        value: furloState,
                        child: content,
                      ),
              );
            },
            theme: themeSettings.themeData,
            home: _AuthGate(
              authService: widget.authService,
              accountOnboardingRepository: widget.accountOnboardingRepository,
              firebaseInitError: widget.firebaseInitError,
              repositoryOverride: widget.repository,
              repositoryFactory: widget.repositoryFactory,
              notificationServiceOverride: widget.notificationService,
              onFurloState: _handleFurloState,
            ),
          ),
        );
      },
    ),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.authService,
    required this.accountOnboardingRepository,
    required this.firebaseInitError,
    required this.repositoryOverride,
    required this.repositoryFactory,
    required this.notificationServiceOverride,
    required this.onFurloState,
  });

  final AuthService? authService;
  final AccountOnboardingRepository? accountOnboardingRepository;
  final String? firebaseInitError;
  final PetRepository? repositoryOverride;
  final PetRepository Function(String storageScope)? repositoryFactory;
  final NotificationService? notificationServiceOverride;
  final void Function(FurloState?) onFurloState;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthUser?>? _authSubscription;
  AuthUser? _user;
  bool _isLoading = true;
  bool _hasAuthError = false;
  bool _startupStarted = false;
  bool _accountStatusLoaded = false;
  bool _accountStatusError = false;
  String? _accountStatusReason;
  bool _requiresFirstPet = false;
  int _sessionGeneration = 0;
  Future<void> _notificationTask = Future<void>.value();
  PetRepository? _repository;
  NotificationSettingsRepository? _notificationSettings;
  NotificationService? _notificationService;
  FurloState? _furloState;

  @override
  void initState() {
    super.initState();
    _listenForAuthChanges();
  }

  @override
  void didUpdateWidget(covariant _AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService ||
        oldWidget.firebaseInitError != widget.firebaseInitError) {
      unawaited(_authSubscription?.cancel());
      _resetSession();
      _isLoading = true;
      _hasAuthError = false;
      _listenForAuthChanges();
    }
  }

  bool _isCurrentSession(int generation) =>
      mounted && generation == _sessionGeneration;

  void _listenForAuthChanges() {
    final service = widget.authService;
    if (widget.firebaseInitError != null || service == null) {
      _isLoading = false;
      return;
    }
    _authSubscription = service.authStateChanges.listen(
      (user) {
        if (!mounted) return;
        final changedUser = _user?.uid != user?.uid;
        final previousStartupStarted = _startupStarted;
        if (changedUser && previousStartupStarted) {
          widget.onFurloState(null);
          _resetSession();
        }
        setState(() {
          _isLoading = false;
          _hasAuthError = false;
          _user = user;
        });
        if (user != null && !_startupStarted) _startSession(user.uid);
      },
      onError: (Object error, StackTrace stackTrace) {
        logAppDiagnostic('Auth stream error received.');
        if (!mounted) return;
        widget.onFurloState(null);
        _resetSession();
        setState(() {
          _isLoading = false;
          _user = null;
          _hasAuthError = true;
        });
      },
    );
  }

  void _resetSession() {
    _startupStarted = false;
    _accountStatusLoaded = false;
    _accountStatusError = false;
    _accountStatusReason = null;
    _requiresFirstPet = false;
    _sessionGeneration++;
    final previousUserScope = _user?.uid;
    final previousState = _furloState;
    previousState?.resetForSession();
    previousState?.dispose();
    final previousNotificationService = _notificationService;
    if (previousNotificationService != null) {
      final cleanupFuture = _notificationTask
          .then((_) async {
            if (previousUserScope == null) return;
            await previousNotificationService.clearScheduled();
          })
          .catchError((Object _) {
            logAppDiagnostic('Notification cleanup failed.');
          });
      _notificationTask = cleanupFuture;
      unawaited(cleanupFuture);
    }
    _repository = null;
    _notificationSettings = null;
    _notificationService = null;
    _furloState = null;
  }

  void _startSession(String uid) {
    _startupStarted = true;
    final generation = ++_sessionGeneration;
    _repository =
        widget.repositoryOverride ??
        widget.repositoryFactory?.call(uid) ??
        createPetRepository(storageScope: uid);
    _notificationSettings = SharedPreferencesNotificationSettingsRepository(
      storageScope: uid,
    );
    _notificationService =
        widget.notificationServiceOverride ??
        createNotificationService(
          repository: _repository!,
          settings: _notificationSettings!,
          storageScope: uid,
        );
    _furloState = FurloState(_repository!);
    widget.onFurloState(_furloState);
    _accountStatusLoaded = false;
    _accountStatusError = false;
    _accountStatusReason = null;
    final migrateLocalData =
        widget.repositoryOverride == null && widget.repositoryFactory == null;
    unawaited(_loadAccountStatus(uid, generation));
    final furloState = _furloState!;
    final notificationService = _notificationService!;
    _notificationTask = _notificationTask
        .then((_) async {
          if (!_isCurrentSession(generation)) return;
          if (migrateLocalData) {
            await LegacyLocalMigration(uid: uid, target: _repository!).run();
          }
          if (!_isCurrentSession(generation)) return;
          await furloState.load();
          if (!_isCurrentSession(generation)) return;
          await notificationService.initialize();
          if (!_isCurrentSession(generation)) {
            await notificationService.clearScheduled();
            return;
          }
          await notificationService.rescheduleAll();
          if (!_isCurrentSession(generation)) {
            await notificationService.clearScheduled();
          }
        })
        .catchError((Object _) {
          logAppDiagnostic('Notification startup failed.');
        });
  }

  Future<void> _loadAccountStatus(String uid, int generation) async {
    try {
      final requiresFirstPet = await widget.accountOnboardingRepository!
          .requiresFirstPet(uid);
      if (!_isCurrentSession(generation)) return;
      setState(() {
        _requiresFirstPet = requiresFirstPet;
        _accountStatusLoaded = true;
        _accountStatusError = false;
      });
    } catch (error) {
      final reason = _describeError(error);
      logAppDiagnostic('Account setup status could not be loaded: $reason');
      if (!_isCurrentSession(generation)) return;
      setState(() {
        _accountStatusError = true;
        _accountStatusLoaded = true;
        _accountStatusReason = reason;
      });
    }
  }

  /// Short, non-sensitive cause: the platform error code when there is one,
  /// otherwise the error type. Never the payload.
  String _describeError(Object error) =>
      error is FirebaseException ? error.code : error.runtimeType.toString();

  Future<void> _markFirstPetComplete() async {
    final uid = _user?.uid;
    if (uid == null) throw StateError('No active account.');
    await widget.accountOnboardingRepository!.markFirstPetComplete(uid);
    if (!mounted) return;
    setState(() => _requiresFirstPet = false);
  }

  Future<void> _retryAccountStatus() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final generation = _sessionGeneration;
    setState(() {
      _accountStatusLoaded = false;
      _accountStatusError = false;
      _accountStatusReason = null;
    });
    await _loadAccountStatus(uid, generation);
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _sessionGeneration++;
    final notificationService = _notificationService;
    final hasAccountSession = _user != null;
    if (notificationService != null) {
      _notificationTask = _notificationTask
          .then((_) async {
            if (!hasAccountSession) return;
            await notificationService.clearScheduled();
          })
          .catchError((Object _) {
            logAppDiagnostic('Notification cleanup failed.');
          });
      unawaited(_notificationTask);
    }
    _furloState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseInitError != null ||
        widget.authService == null ||
        widget.accountOnboardingRepository == null) {
      return const _CloudSetupError();
    }
    if (_hasAuthError) return const _CloudSetupError();
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) return SignInScreen(authService: widget.authService!);
    final repository = _repository;
    final notificationSettings = _notificationSettings;
    final notificationService = _notificationService;
    final furloState = _furloState;
    if (repository == null ||
        notificationSettings == null ||
        notificationService == null ||
        furloState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_accountStatusLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accountStatusError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your account setup could not be loaded.'),
              if (_accountStatusReason != null) ...[
                const SizedBox(height: 8),
                Text('Support code: $_accountStatusReason'),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _retryAccountStatus,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return ChangeNotifierProvider<FurloState>.value(
      value: furloState,
      child: _StartupGate(
        accountOnboardingRepository: widget.accountOnboardingRepository,
        requiresFirstPet: _requiresFirstPet,
        onFirstPetSaved: _markFirstPetComplete,
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
        storageScope: _user!.uid,
      ),
    );
  }
}

class _CloudSetupError extends StatelessWidget {
  const _CloudSetupError();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text("Furlo can't start right now. Please try again later."),
      ),
    ),
  );
}

class _StartupGate extends StatelessWidget {
  const _StartupGate({
    required this.accountOnboardingRepository,
    required this.requiresFirstPet,
    required this.onFirstPetSaved,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
    required this.storageScope,
  });

  final AccountOnboardingRepository? accountOnboardingRepository;
  final bool requiresFirstPet;
  final Future<void> Function() onFirstPetSaved;
  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;
  final String storageScope;

  @override
  Widget build(BuildContext context) {
    // Rebuild only while loading or after a load failure — not on every
    // pet or selection change that flows through FurloState.
    final isLoading = context.select<FurloState, bool>((s) => s.isLoading);
    final loadError = context.select<FurloState, Object?>((s) => s.loadError);
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your pets could not be loaded.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: context.read<FurloState>().load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (!requiresFirstPet) {
      return HomeScreen(
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
        storageScope: storageScope,
      );
    }
    return AddPetScreen(
      repository: repository,
      notificationSettings: notificationSettings,
      notificationService: notificationService,
      storageScope: storageScope,
      accountOnboardingRepository: accountOnboardingRepository,
      onFirstPetSaved: onFirstPetSaved,
    );
  }
}
