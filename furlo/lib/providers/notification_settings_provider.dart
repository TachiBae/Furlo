import 'package:flutter/foundation.dart';

import '../repositories/notification_settings_repository.dart';
import '../services/notifications_service.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider({
    required this.repository,
    required this.service,
  }) {
    ready = load();
  }

  final NotificationSettingsRepository repository;
  final NotificationService service;
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
    _loading = true;
    notifyListeners();
    _settings = await repository.getAll();
    if (isWeb) {
      _permissionGranted = true;
    } else {
      _permissionGranted = await service.hasPermission();
      if (!await repository.permissionWasRequested()) {
        await _requestOnce();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> toggle(String type, bool enabled) async {
    if (_busy || !NotificationTypes.all.contains(type)) return;
    _busy = true;
    _settings = {..._settings, type: enabled};
    notifyListeners();
    try {
      await repository.setEnabled(type, enabled);
      if (!enabled) {
        await service.cancelAllOfType(type);
      } else {
        if (!isWeb &&
            _permissionGranted != true &&
            !await repository.permissionWasRequested()) {
          await _requestOnce();
        }
        if (_permissionGranted == true) await service.rescheduleAll();
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _requestOnce() async {
    await repository.markPermissionRequested();
    _permissionGranted = await service.requestPermission();
  }

  Future<void> refreshPermission() async {
    if (isWeb) return;
    _permissionGranted = await service.hasPermission();
    notifyListeners();
    if (_permissionGranted == true) await service.rescheduleAll();
  }

  Future<void> openSettings() async {
    await service.openAppSettings();
  }
}
