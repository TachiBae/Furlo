import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/furlo_state.dart';
import 'providers/session_controller.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/notification_settings_repository.dart';
import 'repositories/pet_repository.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pets/pet_onboarding_screen.dart';
import 'services/account_onboarding_repository.dart';
import 'services/auth_service.dart';
import 'services/notifications_service.dart';
import 'utils/app_copy.dart';
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
    this.themeSettings,
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

  /// Theme settings already restored before runApp. Without them the app
  /// restores the saved theme itself and shows a splash meanwhile, which
  /// flashes the Default palette for Light and Dark users.
  final ThemeSettings? themeSettings;

  @override
  State<FurloApp> createState() => _FurloAppState();
}

class _FurloAppState extends State<FurloApp> {
  late final ThemeSettings _themeSettings =
      widget.themeSettings ?? ThemeSettings();
  // Null when the theme was restored before runApp: no splash frame at all.
  Future<void>? _themeLoad;
  FurloState? _furloState;

  void _handleFurloState(FurloState? state) {
    if (!mounted) return;
    setState(() => _furloState = state);
  }

  @override
  void initState() {
    super.initState();
    if (widget.themeSettings == null) _themeLoad = _themeSettings.load();
  }

  @override
  void dispose() {
    // Settings passed in belong to main(); only dispose ones made here.
    if (widget.themeSettings == null) _themeSettings.dispose();
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
        if (_themeLoad != null &&
            snapshot.connectionState != ConnectionState.done) {
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
  late SessionController _session = _createSession();
  bool _legacyConsentDialogOpen = false;

  SessionController _createSession() => SessionController(
    authService: widget.authService,
    accountOnboardingRepository: widget.accountOnboardingRepository,
    accountProfileRepository: widget.accountProfileRepository,
    firebaseInitError: widget.firebaseInitError,
    repositoryOverride: widget.repositoryOverride,
    repositoryFactory: widget.repositoryFactory,
    notificationServiceOverride: widget.notificationServiceOverride,
    legacyConsentEnabled: widget.legacyConsentEnabled,
    onFurloState: widget.onFurloState,
  )..addListener(_onSessionChanged);

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService ||
        oldWidget.firebaseInitError != widget.firebaseInitError) {
      // A different backend is a different session entirely.
      _session
        ..removeListener(_onSessionChanged)
        ..dispose();
      _session = _createSession();
    }
  }

  @override
  void dispose() {
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  void _scheduleLegacyConsentDialog() {
    final session = _session;
    final uid = session.user?.uid;
    if (uid == null ||
        _legacyConsentDialogOpen ||
        !mounted ||
        !session.legacyConsentPending) {
      return;
    }
    // The question stays bound to the account and session that were on screen
    // when it was asked: every save uses this captured uid, and a session
    // switch pops the dialog before any answer can be recorded.
    final generation = session.sessionGeneration;
    final navigator = Navigator.of(context);
    _legacyConsentDialogOpen = true;
    session.closeLegacyConsentDialog = () {
      if (navigator.mounted && navigator.canPop()) navigator.pop();
    };
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _LegacyImportDialog(
          onNotNow: () async {
            if (generation != session.sessionGeneration) {
              // The session changed while the dialog was open: close it and
              // save nothing for either account.
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              return;
            }
            final recorded = await session.declineLegacyImport(uid, generation);
            if (!recorded || !mounted) return;
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          onImport: () async {
            if (generation != session.sessionGeneration) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              return;
            }
            final outcome = await session.approveLegacyImport(uid, generation);
            if (!mounted) return;
            switch (outcome) {
              case LegacyImportOutcome.stale:
                return;
              case LegacyImportOutcome.failed:
                // The dialog stays open, so a retry resumes the same copy.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The import could not finish. Please try again.',
                    ),
                  ),
                );
              case LegacyImportOutcome.done:
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }
          },
        ),
      ).whenComplete(() {
        _legacyConsentDialogOpen = false;
        session.closeLegacyConsentDialog = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session.legacyConsentPending) {
      // A route cannot be pushed during build, so the consent dialog is
      // scheduled for the frame that follows this one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session.legacyConsentPending) {
          _scheduleLegacyConsentDialog();
        }
      });
    }
    if (session.cannotStart || session.hasAuthError) {
      return const _CloudSetupError();
    }
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = session.user;
    if (user == null) return SignInScreen(authService: widget.authService!);
    final repository = session.repository;
    final notificationSettings = session.notificationSettings;
    final notificationService = session.notificationService;
    final furloState = session.furloState;
    if (repository == null ||
        notificationSettings == null ||
        notificationService == null ||
        furloState == null ||
        !session.accountStatusLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.accountStatusError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your account setup could not be loaded.'),
              if (session.accountStatusReason != null) ...[
                const SizedBox(height: 8),
                Text('Support code: ${session.accountStatusReason}'),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: session.retryAccountStatus,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (session.profileRequired) {
      return CompleteProfileScreen(
        authService: widget.authService!,
        profileRepository: session.profileRepository,
        appSettings: SharedPreferencesAppSettingsRepository(
          storageScope: user.uid,
        ),
        uid: user.uid,
        onCompleted: session.markProfileComplete,
      );
    }
    return ChangeNotifierProvider<FurloState>.value(
      value: furloState,
      child: _StartupGate(
        accountOnboardingRepository: widget.accountOnboardingRepository,
        requiresFirstPet: session.requiresFirstPet,
        setupComplete: session.setupComplete,
        onFirstPetSaved: session.markFirstPetComplete,
        repository: repository,
        notificationSettings: notificationSettings,
        notificationService: notificationService,
        storageScope: user.uid,
        onDeleteAccount: session.deleteAccount,
        appSettings: AccountSyncedAppSettingsRepository(
          local: SharedPreferencesAppSettingsRepository(storageScope: user.uid),
          profile: session.profileRepository,
          uid: user.uid,
        ),
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
    required this.setupComplete,
    required this.onFirstPetSaved,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
    required this.storageScope,
    required this.appSettings,
    required this.onDeleteAccount,
  });

  final AccountOnboardingRepository? accountOnboardingRepository;
  final bool requiresFirstPet;
  final bool setupComplete;
  final Future<void> Function() onFirstPetSaved;
  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;
  final String storageScope;
  final AppSettingsRepository appSettings;
  final Future<void> Function(String? password) onDeleteAccount;

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
              const Text(AppCopy.checkConnection, textAlign: TextAlign.center),
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
    // A failed refresh with pets already loaded falls through to the
    // dashboard, which keeps them on screen and shows its own retry banner.
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
      appSettings: appSettings,
      onDeleteAccount: onDeleteAccount,
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
