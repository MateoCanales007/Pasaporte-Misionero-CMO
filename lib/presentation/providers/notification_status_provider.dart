import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository_providers.dart';
import 'session_providers.dart';

class NotificationDeviceStatus {
  const NotificationDeviceStatus({required this.supported, required this.enabled, required this.promptDismissed});

  final bool supported;
  final bool enabled;
  final bool promptDismissed;

  bool get shouldPrompt => supported && !enabled && !promptDismissed;
}

final sharedPreferencesAsyncProvider = Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

/// Estado de las notificaciones en este dispositivo.
final notificationStatusProvider = AsyncNotifierProvider<NotificationStatusNotifier, NotificationDeviceStatus>(
  NotificationStatusNotifier.new,
);

class NotificationStatusNotifier extends AsyncNotifier<NotificationDeviceStatus> {
  static const _dismissedKey = 'notification_prompt_dismissed';

  @override
  Future<NotificationDeviceStatus> build() async {
    final repo = ref.watch(notificationRepositoryProvider);
    if (!repo.isSupported) {
      return const NotificationDeviceStatus(supported: false, enabled: false, promptDismissed: true);
    }
    final prefs = ref.watch(sharedPreferencesAsyncProvider);
    return NotificationDeviceStatus(
      supported: true,
      enabled: await repo.isEnabledOnThisDevice(),
      promptDismissed: await prefs.getBool(_dismissedKey) ?? false,
    );
  }

  /// Devuelve `false` si el usuario no concedió el permiso.
  Future<bool> enable() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    final granted = await ref.read(notificationRepositoryProvider).enableOnThisDevice(uid);
    await ref.read(sharedPreferencesAsyncProvider).setBool(_dismissedKey, true);
    ref.invalidateSelf();
    return granted;
  }

  Future<void> disable() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(notificationRepositoryProvider).disableOnThisDevice(uid);
    ref.invalidateSelf();
  }

  Future<void> dismissPrompt() async {
    await ref.read(sharedPreferencesAsyncProvider).setBool(_dismissedKey, true);
    ref.invalidateSelf();
  }
}
