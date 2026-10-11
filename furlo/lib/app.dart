import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/furlo_state.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/notification_settings_repository.dart';
import 'repositories/pet_repository.dart';
import 'screens/auth/complete_profile_screen.dart';
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
    this.accountProfileRepository,
    this.firebaseInitError,
    this.repositoryFactory,
    this.legacyConsentEnabled,
  });

  final PetRepository? repository;
  final NotificationService? notificationService;
  final AuthService? authService;
  final AccountOnboardingRepository? accountOnboardingRepository;
  final AccountProfileRepository? accountProfileRepository;
  final String? firebaseInitError;
  final PetRepository Function(String storageScope)? repositoryFactory;

  /// Forces the pre-account import consent flow on or off. Null (the default,
  /// including production) enables it outside a test harness; tests opt in.
  final bool? legacyConsentEnabled;

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
              accountProfileRepository: widget.accountProfileRepository,
              firebaseInitError: widget.firebaseInitError,
              repositoryOverride: widget.repository,
              repositoryFactory: widget.repositoryFactory,
              notificationServiceOverride: widget.notificationService,
              legacyConsentEnabled: widget.legacyConsentEnabled,
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
    required this.accountProfileRepository,
    required this.firebaseInitError,
    required this.repositoryOverride,
    required this.repositoryFactory,
    required this.notificationServiceOverride,
    required this.legacyConsentEnabled,
    required this.onFurloState,
  });

  final AuthService? authService;
  final AccountOnboardingRepository? accountOnboardingRepository;
  final AccountProfileRepository? accountProfileRepository;
  final String? firebaseInitError;
  final PetRepository? repositoryOverride;
  final PetRepository Function(String storageScope)? repositoryFactory;
  final NotificationService? notificationServiceOverride;
  final bool? legacyConsentEnabled;
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
  bool _profileRequired = false;
  bool _setupComplete = false;
  int _sessionGeneration = 0;
  Future<void> _notificationTask = Future<void>.value();
  PetRepository? _repository;
  NotificationSettingsRepository? _notificationSettings;
  NotificationService? _notificationService;
  AccountProfileRepository? _profileRepository;
  FurloState? _furloState;
  bool _legacyConsentPending = false;
  bool _legacyConsentDialogOpen = false;
  VoidCallback? _closeLegacyConsentDialog;

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
    _profileRequired = false;
    _setupComplete = false;
    _legacyConsentPending = false;
    // Close the consent dialog without recording an answer: its question was
    // bound to the account and session that are now gone.
    final closeConsentDialog = _closeLegacyConsentDialog;
    _closeLegacyConsentDialog = null;
    closeConsentDialog?.call();
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
    _profileRepository = null;
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
    // With an injected repository the app runs against a test harness rather
    // than a Firebase project, so the completion step is never required there.
    final testHarness =
        widget.repositoryOverride != null || widget.repositoryFactory != null;
    _profileRepository =
        widget.accountProfileRepository ??
        (testHarness
            ? const NoOpAccountProfileRepository()
            : FirestoreAccountProfileRepository());
    _accountStatusLoaded = false;
    _accountStatusError = false;
    _accountStatusReason = null;
    final migrateLocalData =
        widget.repositoryOverride == null && widget.repositoryFactory == null;
    // Consent is always on in the real app; inside an injected-repository
    // harness it is opt-in so existing harness tests keep their behavior.
    final legacyConsentActive = widget.legacyConsentEnabled ?? migrateLocalData;
    unawaited(_loadAccountStatus(uid, generation));
    final furloState = _furloState!;
    final notificationService = _notificationService!;
    _notificationTask = _notificationTask
        .then((_) async {
          if (!_isCurrentSession(generation)) return;
          if (legacyConsentActive) {
            await _resolveLegacyImport(
              uid,
              generation,
              migrateLocalData: migrateLocalData,
            );
          }
          if (!_isCurrentSession(generation)) return;
          await furloState.load();
          if (!_isCurrentSession(generation)) return;
          if (furloState.pets.isNotEmpty) {
            await _backfillSetupMarker(uid, generation);
          }
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
      final profile =
          _profileRepository ?? const NoOpAccountProfileRepository();
      final profileRequired = await profile.requiresProfileCompletion(uid);
      final setupComplete = await profile.isSetupComplete(uid);
      if (!_isCurrentSession(generation)) return;
      setState(() {
        _requiresFirstPet = requiresFirstPet;
        _profileRequired = profileRequired;
        _setupComplete = setupComplete;
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
    await (_profileRepository ?? const NoOpAccountProfileRepository())
        .markSetupComplete(uid);
    if (!mounted) return;
    setState(() {
      _requiresFirstPet = false;
      _setupComplete = true;
    });
  }

  /// Gives accounts that already own pets the setup marker, so deleting the
  /// last pet later cannot send them back to onboarding.
  ///
  /// Best-effort: a missing marker is recovered on the next launch.
  Future<void> _backfillSetupMarker(String uid, int generation) async {
    final profile = _profileRepository ?? const NoOpAccountProfileRepository();
    try {
      if (await profile.isSetupComplete(uid)) {
        if (_isCurrentSession(generation) && mounted) {
          setState(() => _setupComplete = true);
        }
        return;
      }
      if (!_isCurrentSession(generation)) return;
      await profile.markSetupComplete(uid);
      if (!_isCurrentSession(generation)) return;
      if (mounted) setState(() => _setupComplete = true);
    } catch (error, stackTrace) {
      debugPrint('Setup marker could not be recorded: $error\n$stackTrace');
    }
  }

  Future<void> _markProfileComplete() async {
    if (!mounted) return;
    setState(() => _profileRequired = false);
  }

  /// Migration wired for the current environment: Firestore marker and
  /// platform stores in the real app; account-scoped local marker and web
  /// stores under an injected-repository harness, which has no Firebase.
  LegacyLocalMigration _legacyMigration(String uid) {
    final testHarness =
        widget.repositoryOverride != null || widget.repositoryFactory != null;
    return LegacyLocalMigration(
      uid: uid,
      target: _repository!,
      marker: testHarness ? SharedPreferencesMigrationMarker(uid: uid) : null,
      // Only the device-wide store: under a harness the account-scoped local
      // store is the target itself, so including it would copy the target
      // onto itself.
      legacySources: testHarness
          ? [WebPetRepository(storageScope: null)]
          : null,
    );
  }

  /// Consent gate for pre-account device data: nothing is copied until the
  /// signed-in account answers the dialog. An account that already answered
  /// imports (or keeps declining) without being asked again, and data that is
  /// not pre-account keeps the original silent path.
  Future<void> _resolveLegacyImport(
    String uid,
    int generation, {
    required bool migrateLocalData,
  }) async {
    try {
      final settings = SharedPreferencesAppSettingsRepository(
        storageScope: uid,
      );
      final choice = await settings.getLegacyImportChoice();
      if (choice ==
          SharedPreferencesAppSettingsRepository.legacyImportDeclined) {
        return;
      }
      final migration = _legacyMigration(uid);
      if (choice ==
          SharedPreferencesAppSettingsRepository.legacyImportApproved) {
        await migration.run();
        return;
      }
      if (await migration.hasPreAccountData()) {
        if (!_isCurrentSession(generation) || !mounted) return;
        setState(() => _legacyConsentPending = true);
        return;
      }
      if (migrateLocalData) await migration.run();
    } catch (error, stackTrace) {
      debugPrint('Legacy import check failed: $error\n$stackTrace');
    }
  }

  void _scheduleLegacyConsentDialog() {
    final uid = _user?.uid;
    if (uid == null ||
        _legacyConsentDialogOpen ||
        !mounted ||
        !_legacyConsentPending) {
      return;
    }
    // The question stays bound to the account and session that were on screen
    // when it was asked: every save uses this captured uid, and a session
    // switch pops the dialog before any answer can be recorded.
    final generation = _sessionGeneration;
    final navigator = Navigator.of(context);
    _legacyConsentDialogOpen = true;
    _closeLegacyConsentDialog = () {
      if (navigator.mounted && navigator.canPop()) navigator.pop();
    };
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _LegacyImportDialog(
          onNotNow: () async {
            if (generation != _sessionGeneration) {
              // The session changed while the dialog was open: close it and
              // save nothing for either account.
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              return;
            }
            final settings = SharedPreferencesAppSettingsRepository(
              storageScope: uid,
            );
            await settings.setLegacyImportChoice(
              SharedPreferencesAppSettingsRepository.legacyImportDeclined,
            );
            if (!mounted || generation != _sessionGeneration) return;
            setState(() => _legacyConsentPending = false);
            _closeLegacyConsentDialog = null;
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          onImport: () async {
            if (generation != _sessionGeneration) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              return;
            }
            final settings = SharedPreferencesAppSettingsRepository(
              storageScope: uid,
            );
            final resume = await settings.isLegacyImportInProgress();
            if (!mounted || generation != _sessionGeneration) return;
            await settings.setLegacyImportInProgress(true);
            try {
              await _legacyMigration(uid).importNow(resumePartial: resume);
            } catch (_) {
              // importNow logged the real error; the choice stays unsaved and
              // the dialog stays open, so a retry resumes the same copy.
              if (!mounted || generation != _sessionGeneration) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'The import could not finish. Please try again.',
                  ),
                ),
              );
              return;
            }
            if (!mounted || generation != _sessionGeneration) return;
            await settings.setLegacyImportChoice(
              SharedPreferencesAppSettingsRepository.legacyImportApproved,
            );
            await settings.setLegacyImportInProgress(false);
            if (!mounted || generation != _sessionGeneration) return;
            setState(() => _legacyConsentPending = false);
            _closeLegacyConsentDialog = null;
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            await _furloState?.load();
            if (!_isCurrentSession(generation) || !mounted) return;
            if (_furloState?.pets.isNotEmpty ?? false) {
              await _backfillSetupMarker(uid, generation);
            }
          },
        ),
      ).whenComplete(() {
        _legacyConsentDialogOpen = false;
        _closeLegacyConsentDialog = null;
      }),
    );
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
    if (_legacyConsentPending) {
      // A route cannot be pushed during build, so the consent dialog is
      // scheduled for the frame that follows this one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _legacyConsentPending) _scheduleLegacyConsentDialog();
      });
    }
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
    if (_profileRequired) {
      return CompleteProfileScreen(
        authService: widget.authService!,
        profileRepository:
            _profileRepository ?? const NoOpAccountProfileRepository(),
        appSettings: SharedPreferencesAppSettingsRepository(
          storageScope: _user!.uid,
        ),
        uid: _user!.uid,
        onCompleted: _markProfileComplete,
      );
    }
    return ChangeNotifierProvider<FurloState>.value(
      value: furloState,
      child: _StartupGate(
        accountOnboardingRepository: widget.accountOnboardingRepository,
        requiresFirstPet: _requiresFirstPet,
        setupComplete: _setupComplete,
        onFirstPetSaved: _markFirstPetComplete,
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
        storageScope: _user!.uid,
      ),
    );
  }
}

/// Small inline error that keeps the loaded page usable underneath it.
///
/// Mirrors the reminders error card on the home dashboard: surface-coloured
/// rounded container, secondary body text, one retry action.
class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: AppRadius.lgRadius,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Your pets could not be refreshed.',
            style: AppTypography.body.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
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
    required this.setupComplete,
    required this.onFirstPetSaved,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
    required this.storageScope,
  });

  final AccountOnboardingRepository? accountOnboardingRepository;
  final bool requiresFirstPet;
  final bool setupComplete;
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
    final hasPets = context.select<FurloState, bool>((s) => s.pets.isNotEmpty);
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadError != null && !hasPets) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your pets could not be loaded.'),
              const SizedBox(height: 8),
              const Text(
                'Check your connection, then try again.',
                textAlign: TextAlign.center,
              ),
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
    if (loadError != null) {
      // Pets were loaded before this failure: keep them on screen rather than
      // making an offline moment look like deleted data.
      return Column(
        children: [
          _LoadErrorBanner(onRetry: context.read<FurloState>().load),
          Expanded(
            child: HomeScreen(
              repository: repository,
              notificationSettings: notificationSettings,
              notificationService: notificationService,
              storageScope: storageScope,
            ),
          ),
        ],
      );
    }
    if (requiresFirstPet || (!setupComplete && !hasPets)) {
      return AddPetScreen(
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
        storageScope: storageScope,
        accountOnboardingRepository: accountOnboardingRepository,
        onFirstPetSaved: onFirstPetSaved,
      );
    }
    return HomeScreen(
      repository: repository,
      notificationSettings: notificationSettings,
      notificationService: notificationService,
      storageScope: storageScope,
    );
  }
}

/// The one-question consent dialog for importing pre-account device data.
///
/// Styled like the app's other dialogs: surface background, title, body, and
/// secondary/primary actions.
class _LegacyImportDialog extends StatelessWidget {
  const _LegacyImportDialog({required this.onNotNow, required this.onImport});

  final Future<void> Function() onNotNow;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.appColors.surface,
    title: const Text('Import pets from this device?'),
    content: const Text(
      'This device has pets saved before accounts. Import them into this account?',
    ),
    actions: [
      TextButton(onPressed: () => onNotNow(), child: const Text('Not now')),
      FilledButton(onPressed: () => onImport(), child: const Text('Import')),
    ],
  );
}
