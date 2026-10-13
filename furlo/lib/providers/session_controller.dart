import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../repositories/app_settings_repository.dart';
import '../repositories/notification_settings_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/account_repository.dart';
import '../services/auth_service.dart';
import '../services/legacy_local_migration.dart';
import '../services/notifications_service.dart';
import '../utils/app_diagnostics.dart';
import 'furlo_state.dart';

/// How an answer to the pre-account import question ended.
enum LegacyImportOutcome {
  /// The session changed while answering; nothing was recorded for it.
  stale,

  /// The copy failed; the answer stays unrecorded so a retry resumes it.
  failed,

  /// Recorded for the current session.
  done,
}

/// One signed-in session: who is signed in, the stores built for them, the
/// account's setup status, and the pre-account import question.
///
/// Every async step captures the session generation it started in and drops
/// its result if the account changed meanwhile, so one account's work can
/// never land in another's session. The widget layer only routes on this
/// state and owns what needs a BuildContext (dialogs, SnackBars).
class SessionController extends ChangeNotifier {
  SessionController({
    required this.authService,
    required this.accountOnboardingRepository,
    required this.accountProfileRepository,
    required this.firebaseInitError,
    required this.repositoryOverride,
    required this.repositoryFactory,
    required this.notificationServiceOverride,
    required this.legacyConsentEnabled,
    required this.onFurloState,
  }) {
    _listenForAuthChanges();
  }

  final AuthService? authService;
  final AccountOnboardingRepository? accountOnboardingRepository;
  final AccountProfileRepository? accountProfileRepository;
  final String? firebaseInitError;
  final PetRepository? repositoryOverride;
  final PetRepository Function(String storageScope)? repositoryFactory;
  final NotificationService? notificationServiceOverride;
  final bool? legacyConsentEnabled;
  final void Function(FurloState?) onFurloState;

  StreamSubscription<AuthUser?>? _authSubscription;
  bool _disposed = false;
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

  /// Set by the widget while the consent dialog is open; a session change
  /// calls it to close the dialog without recording an answer.
  VoidCallback? closeLegacyConsentDialog;

  AuthUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get hasAuthError => _hasAuthError;
  bool get accountStatusLoaded => _accountStatusLoaded;
  bool get accountStatusError => _accountStatusError;
  String? get accountStatusReason => _accountStatusReason;
  bool get requiresFirstPet => _requiresFirstPet;
  bool get profileRequired => _profileRequired;
  bool get setupComplete => _setupComplete;
  int get sessionGeneration => _sessionGeneration;
  PetRepository? get repository => _repository;
  NotificationSettingsRepository? get notificationSettings =>
      _notificationSettings;
  NotificationService? get notificationService => _notificationService;
  AccountProfileRepository get profileRepository =>
      _profileRepository ?? const NoOpAccountProfileRepository();
  FurloState? get furloState => _furloState;
  bool get legacyConsentPending => _legacyConsentPending;

  /// The app cannot reach its backend at all.
  bool get cannotStart =>
      firebaseInitError != null ||
      authService == null ||
      accountOnboardingRepository == null;

  bool _isCurrentSession(int generation) =>
      !_disposed && generation == _sessionGeneration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listenForAuthChanges() {
    final service = authService;
    if (firebaseInitError != null || service == null) {
      _isLoading = false;
      return;
    }
    _authSubscription = service.authStateChanges.listen(
      (user) {
        if (_disposed) return;
        final changedUser = _user?.uid != user?.uid;
        final previousStartupStarted = _startupStarted;
        if (changedUser && previousStartupStarted) {
          onFurloState(null);
          _resetSession();
        }
        _isLoading = false;
        _hasAuthError = false;
        _user = user;
        _notify();
        if (user != null && !_startupStarted) _startSession(user.uid);
      },
      onError: (Object error, StackTrace stackTrace) {
        logAppDiagnostic('Auth stream error received.');
        if (_disposed) return;
        onFurloState(null);
        _resetSession();
        _isLoading = false;
        _user = null;
        _hasAuthError = true;
        _notify();
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
    final closeConsentDialog = closeLegacyConsentDialog;
    closeLegacyConsentDialog = null;
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

  bool get _testHarness =>
      repositoryOverride != null || repositoryFactory != null;

  void _startSession(String uid) {
    _startupStarted = true;
    final generation = ++_sessionGeneration;
    _repository =
        repositoryOverride ??
        repositoryFactory?.call(uid) ??
        createPetRepository(storageScope: uid);
    _notificationSettings = SharedPreferencesNotificationSettingsRepository(
      storageScope: uid,
    );
    _notificationService =
        notificationServiceOverride ??
        createNotificationService(
          repository: _repository!,
          settings: _notificationSettings!,
          storageScope: uid,
        );
    _furloState = FurloState(_repository!);
    onFurloState(_furloState);
    // With an injected repository the app runs against a test harness rather
    // than a Firebase project, so the completion step is never required there.
    _profileRepository =
        accountProfileRepository ??
        (_testHarness
            ? const NoOpAccountProfileRepository()
            : FirestoreAccountProfileRepository());
    _accountStatusLoaded = false;
    _accountStatusError = false;
    _accountStatusReason = null;
    final migrateLocalData = !_testHarness;
    // Consent is always on in the real app; inside an injected-repository
    // harness it is opt-in so existing harness tests keep their behavior.
    final legacyConsentActive = legacyConsentEnabled ?? migrateLocalData;
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
      final requiresFirstPet = await accountOnboardingRepository!
          .requiresFirstPet(uid);
      final profile = profileRepository;
      final profileRequired = await profile.requiresProfileCompletion(uid);
      final setupComplete = await profile.isSetupComplete(uid);
      if (!_isCurrentSession(generation)) return;
      _requiresFirstPet = requiresFirstPet;
      _profileRequired = profileRequired;
      _setupComplete = setupComplete;
      _accountStatusLoaded = true;
      _accountStatusError = false;
      _notify();
    } catch (error) {
      final reason = _describeError(error);
      logAppDiagnostic('Account setup status could not be loaded: $reason');
      if (!_isCurrentSession(generation)) return;
      _accountStatusError = true;
      _accountStatusLoaded = true;
      _accountStatusReason = reason;
      _notify();
    }
  }

  /// Short, non-sensitive cause: the platform error code when there is one,
  /// otherwise the error type. Never the payload.
  String _describeError(Object error) =>
      error is FirebaseException ? error.code : error.runtimeType.toString();

  Future<void> retryAccountStatus() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final generation = _sessionGeneration;
    _accountStatusLoaded = false;
    _accountStatusError = false;
    _accountStatusReason = null;
    _notify();
    await _loadAccountStatus(uid, generation);
  }

  Future<void> markFirstPetComplete() async {
    final uid = _user?.uid;
    if (uid == null) throw StateError('No active account.');
    await accountOnboardingRepository!.markFirstPetComplete(uid);
    await profileRepository.markSetupComplete(uid);
    if (_disposed) return;
    _requiresFirstPet = false;
    _setupComplete = true;
    _notify();
  }

  Future<void> markProfileComplete() async {
    if (_disposed) return;
    _profileRequired = false;
    _notify();
  }

  /// Gives accounts that already own pets the setup marker, so deleting the
  /// last pet later cannot send them back to onboarding.
  ///
  /// Best-effort: a missing marker is recovered on the next launch.
  Future<void> _backfillSetupMarker(String uid, int generation) async {
    final profile = profileRepository;
    try {
      if (await profile.isSetupComplete(uid)) {
        if (_isCurrentSession(generation)) {
          _setupComplete = true;
          _notify();
        }
        return;
      }
      if (!_isCurrentSession(generation)) return;
      await profile.markSetupComplete(uid);
      if (!_isCurrentSession(generation)) return;
      _setupComplete = true;
      _notify();
    } catch (error, stackTrace) {
      debugPrint('Setup marker could not be recorded: $error\n$stackTrace');
    }
  }

  /// Deletes the signed-in account and everything it owns, in an order
  /// where a failure never strands the person half-deleted:
  /// 1. confirm who they are (Firebase requires a recent sign-in), so a
  ///    wrong password stops here with nothing removed;
  /// 2. delete the pet data, profile and onboarding records, and this
  ///    device's caches and reminders (each step is safe to repeat);
  /// 3. delete the sign-in account, which signs them out.
  Future<void> deleteAccount(String? password) async {
    final service = authService!;
    final uid = _user?.uid;
    final repository = _repository;
    if (uid == null || repository == null) {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
    await service.reauthenticate(password: password);
    await repository.clearAllData();
    await profileRepository.deleteProfile(uid);
    await accountOnboardingRepository!.deleteAccountRecord(uid);
    await _notificationService?.clearScheduled();
    await _notificationSettings?.clearAll();
    await SharedPreferencesAppSettingsRepository(
      storageScope: uid,
    ).clearDisplayName();
    await service.deleteAccount();
  }

  /// Migration wired for the current environment: Firestore marker and
  /// platform stores in the real app; account-scoped local marker and web
  /// stores under an injected-repository harness, which has no Firebase.
  LegacyLocalMigration _legacyMigration(String uid) => LegacyLocalMigration(
    uid: uid,
    target: _repository!,
    marker: _testHarness ? SharedPreferencesMigrationMarker(uid: uid) : null,
    // Only the device-wide store: under a harness the account-scoped local
    // store is the target itself, so including it would copy the target
    // onto itself.
    legacySources: _testHarness ? [WebPetRepository(storageScope: null)] : null,
  );

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
        if (!_isCurrentSession(generation)) return;
        _legacyConsentPending = true;
        _notify();
        return;
      }
      if (migrateLocalData) await migration.run();
    } catch (error, stackTrace) {
      debugPrint('Legacy import check failed: $error\n$stackTrace');
    }
  }

  /// Records "Not now" for [uid], asked in session [generation].
  /// Returns false when the session changed meanwhile (nothing to close).
  Future<bool> declineLegacyImport(String uid, int generation) async {
    final settings = SharedPreferencesAppSettingsRepository(storageScope: uid);
    await settings.setLegacyImportChoice(
      SharedPreferencesAppSettingsRepository.legacyImportDeclined,
    );
    if (!_isCurrentSession(generation)) return false;
    _legacyConsentPending = false;
    closeLegacyConsentDialog = null;
    _notify();
    return true;
  }

  /// Copies the pre-account data into [uid]'s account, asked in session
  /// [generation]. The answer is recorded only once the copy succeeds, so a
  /// failed attempt can be retried and resumes where it stopped.
  Future<LegacyImportOutcome> approveLegacyImport(
    String uid,
    int generation,
  ) async {
    final settings = SharedPreferencesAppSettingsRepository(storageScope: uid);
    final resume = await settings.isLegacyImportInProgress();
    if (!_isCurrentSession(generation)) return LegacyImportOutcome.stale;
    await settings.setLegacyImportInProgress(true);
    try {
      await _legacyMigration(uid).importNow(resumePartial: resume);
    } catch (_) {
      // importNow logged the real error; the choice stays unsaved.
      return _isCurrentSession(generation)
          ? LegacyImportOutcome.failed
          : LegacyImportOutcome.stale;
    }
    if (!_isCurrentSession(generation)) return LegacyImportOutcome.stale;
    await settings.setLegacyImportChoice(
      SharedPreferencesAppSettingsRepository.legacyImportApproved,
    );
    await settings.setLegacyImportInProgress(false);
    if (!_isCurrentSession(generation)) return LegacyImportOutcome.stale;
    _legacyConsentPending = false;
    closeLegacyConsentDialog = null;
    _notify();
    unawaited(_reloadAfterImport(uid, generation));
    return LegacyImportOutcome.done;
  }

  Future<void> _reloadAfterImport(String uid, int generation) async {
    await _furloState?.load();
    if (!_isCurrentSession(generation)) return;
    if (_furloState?.pets.isNotEmpty ?? false) {
      await _backfillSetupMarker(uid, generation);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    final closeConsentDialog = closeLegacyConsentDialog;
    closeLegacyConsentDialog = null;
    closeConsentDialog?.call();
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
}
