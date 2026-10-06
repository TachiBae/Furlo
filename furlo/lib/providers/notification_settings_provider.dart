import 'package:flutter/foundation.dart';

import '../repositories/notification_settings_repository.dart';
import '../services/notifications_service.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider({
    required this.repository,
    required this.service,
    this.storageScope,
  }) {
    ready = load();
  }

  final NotificationSettingsRepository repository;
  final NotificationService service;
  final String? storageScope;
  int _sessionGeneration = 0;
  Map<String, bool> _settings = {
    for (final type in NotificationTypes.all) type: true,
  };
  bool _loading = true;
  bool? _permissionGranted;
  bool _busy = false;

  Map<String, bool> get settings => Map.unmodifiable(_settings);
  bool get loading => _loading;
  bool? get permissionGranted => _permissionGranted;
  bool get busy => _busy;
  bool get isWeb => kIsWeb;
  late final Future<void> ready;

  bool isEnabled(String type) => _settings[type] ?? true;

  Future<void> load() async {
    final generation = _sessionGeneration;
    _loading = true;
    notifyListeners();
    late final Map<String, bool> settings;
    try {
      settings = await repository.getAll();
    } catch (_) {
      if (generation == _sessionGeneration) {
        _loading = false;
        notifyListeners();
      }
      rethrow;
    }
    if (generation != _sessionGeneration) return;
    _settings = settings;

    if (isWeb) {
      _permissionGranted = true;
    } else {
      _permissionGranted = await service.hasPermission();
      if (generation != _sessionGeneration) return;
      if (!await repository.permissionWasRequested()) {
        await _requestOnce();
        if (generation != _sessionGeneration) return;
        if (_permissionGranted == true) await service.rescheduleAll();
      }
    }
    if (generation != _sessionGeneration) return;
    _loading = false;
    notifyListeners();
  }

  Future<void> toggle(String type, bool enabled) async {
    if (_busy || !NotificationTypes.all.contains(type)) return;
    final generation = _sessionGeneration;
    final previousEnabled = isEnabled(type);
    _busy = true;
    _settings = {..._settings, type: enabled};
    notifyListeners();
    try {
      await repository.setEnabled(type, enabled);
      if (generation != _sessionGeneration) return;
      if (!enabled) {
        await service.cancelAllOfType(type);
      } else {
        if (!isWeb &&
            _permissionGranted != true &&
            !await repository.permissionWasRequested()) {
          if (generation != _sessionGeneration) return;
          await _requestOnce();
        }
        if (generation != _sessionGeneration) return;
        if (_permissionGranted == true) await service.rescheduleAll();
      }
    } catch (_) {
      if (generation != _sessionGeneration) return;
      _settings = {..._settings, type: previousEnabled};
      rethrow;
    } finally {
      if (generation == _sessionGeneration) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _requestOnce() async {
    await repository.markPermissionRequested();
    _permissionGranted = await service.requestPermission();
  }

  Future<void> refreshPermission() async {
    if (isWeb) return;
    final generation = _sessionGeneration;
    final permissionGranted = await service.hasPermission();
    if (generation != _sessionGeneration) return;
    _permissionGranted = permissionGranted;
    notifyListeners();
    if (_permissionGranted == true && generation == _sessionGeneration) {
      await service.rescheduleAll();
    }
  }

  Future<void> openSettings() async {
    await service.openAppSettings();
  }

  @override
  void dispose() {
    _sessionGeneration++;
    super.dispose();
  }
}
