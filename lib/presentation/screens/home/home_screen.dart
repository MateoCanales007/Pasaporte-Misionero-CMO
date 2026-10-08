import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/pending_redemptions_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/dialogs.dart';
import '../community/community_tab.dart';
import '../missions/missions_tab.dart';
import '../passport/passport_tab.dart';
import '../profile/profile_tab.dart';
import '../qr/qr_presenter_screen.dart';
import '../qr/scanner_screen.dart';
import '../sermons/sermons_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<Object>? _messagesSub;

  static const _tabs = <({String label, IconData icon, IconData selectedIcon})>[
    (label: 'Pasaporte', icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book_rounded),
    (label: 'Misiones', icon: Icons.explore_outlined, selectedIcon: Icons.explore_rounded),
    (label: 'Prédicas', icon: Icons.play_circle_outline_rounded, selectedIcon: Icons.play_circle_rounded),
    (label: 'Comunidad', icon: Icons.groups_outlined, selectedIcon: Icons.groups_rounded),
    (label: 'Perfil', icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = ref.read(networkStatusProvider).onlineChanges.listen((online) {
      if (online) _syncPending();
    }, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending();
      _setUpNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncPending();
  }

  /// Reintenta los escaneos guardados sin conexión.
  Future<void> _syncPending() async {
    try {
      await ref.read(pendingRedemptionsProvider.future);
      final summary = await ref.read(pendingRedemptionsProvider.notifier).retry();
      if (summary == null || !mounted) return;
      for (final confirmed in summary.confirmed) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          buildAppSnackBar(
            '¡Sello confirmado! "${confirmed.missionName}" ya está en tu pasaporte.',
            type: SnackType.success,
          ),
        );
      }
      if (summary.failed > 0) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          buildAppSnackBar('Un escaneo no se pudo validar. Revisa tu pasaporte.', type: SnackType.error),
        );
      }
    } catch (_) {
      // Se reintentará en el siguiente cambio de conexión.
    }
  }

  void _setUpNotifications() {
    final notifications = ref.read(notificationRepositoryProvider);
    if (!notifications.isSupported) return;
    final uid = ref.read(currentUidProvider);
    if (uid != null) notifications.refreshRegistration(uid);
    _messagesSub = notifications.foregroundMessages.listen((message) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(buildAppSnackBar('${message.title}\n${message.body}'.trim()));
    }, onError: (_) {});
  }

  Widget? _buildFab() {
    if (_index > 1) return null;
    final canPresent = ref.watch(currentRoleProvider).canPresentQr;
    if (canPresent) {
      return FloatingActionButton.extended(
        heroTag: 'qr-fab',
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        tooltip: 'Mostrar el código QR de la misión activa',
        icon: const Icon(Icons.qr_code_2_rounded, size: 28, color: AppColors.yellow),
        label: const Text('MOSTRAR QR'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrPresenterScreen())),
      );
    }
    return FloatingActionButton.extended(
      heroTag: 'scan-fab',
      backgroundColor: AppColors.amber,
      foregroundColor: AppColors.onAmber,
      tooltip: 'Escanear el código QR de la misión',
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
      label: const Text('ESCANEAR SELLO'),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene activos los escaneos pendientes para poder reintentarlos.
    ref.watch(pendingRedemptionsProvider);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Pasaporte Virtual CMO')),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            const PassportTab(),
            MissionsTab(onScanRequested: _openScanner),
            const SermonsTab(),
            const CommunityTab(),
            const ProfileTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
              tooltip: tab.label,
            ),
        ],
      ),
    );
  }

  void _openScanner() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
}
