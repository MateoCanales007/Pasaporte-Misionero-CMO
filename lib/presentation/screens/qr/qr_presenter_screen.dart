import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/qr_models.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/state_views.dart';

/// Muestra el QR temporal de la misión activa y lo renueva antes de vencer.
/// Solo funciona para presentadores y administradores (el servidor lo valida).
class QrPresenterScreen extends ConsumerStatefulWidget {
  const QrPresenterScreen({super.key});

  @override
  ConsumerState<QrPresenterScreen> createState() => _QrPresenterScreenState();
}

class _QrPresenterScreenState extends ConsumerState<QrPresenterScreen> {
  static const _retryDelay = Duration(seconds: 5);

  QrIssueResult? _result;
  Object? _error;
  String? _missionId;
  bool _loading = true;
  bool _refreshFailed = false;
  final Stopwatch _age = Stopwatch();
  Timer? _refreshTimer;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _fetch();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ticker?.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  QrTokenIssued? get _issued => _result is QrTokenIssued ? _result as QrTokenIssued : null;

  bool get _expired => _issued != null && _age.elapsed >= _issued!.lifetime;

  Future<void> _fetch() async {
    _refreshTimer?.cancel();
    setState(() => _loading = true);
    try {
      final result = await ref.read(stampRepositoryProvider).issueQrToken(missionId: _missionId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
        _refreshFailed = false;
      });
      if (result is QrTokenIssued) {
        _missionId = result.missionId;
        _age
          ..reset()
          ..start();
        _refreshTimer = Timer(result.refreshAfter, _fetch);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // Si ya hay un QR vigente se sigue mostrando mientras se reintenta.
        if (_issued == null || _expired) _error = error;
        _refreshFailed = true;
      });
      if (error is! PermissionDeniedException) _refreshTimer = Timer(_retryDelay, _fetch);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _chooseMission(String id) {
    _missionId = id;
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final canPresent = ref.watch(currentRoleProvider).canPresentQr;
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('Código QR de la misión')),
      body: SafeArea(child: canPresent ? _buildBody(context) : _notAllowed()),
    );
  }

  Widget _notAllowed() => const _WhitePanel(
    child: ErrorView(error: PermissionDeniedException('Solo los presentadores autorizados pueden mostrar el QR.')),
  );

  Widget _buildBody(BuildContext context) {
    final issued = _issued;
    if (_error != null && (issued == null || _expired)) {
      return _WhitePanel(
        child: ErrorView(error: _error!, onRetry: _loading ? null : _fetch),
      );
    }
    if (issued == null) {
      return switch (_result) {
        NoActiveMission() => _WhitePanel(
          child: EmptyView(
            icon: Icons.event_busy_rounded,
            title: 'No hay ninguna misión activa en este momento',
            message: 'El código aparece solo durante el horario de una misión activa.',
            action: FilledButton.icon(
              onPressed: _loading ? null : _fetch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a revisar'),
            ),
          ),
        ),
        ChooseMission(:final options) => _WhitePanel(
          child: _MissionChooser(options: options, onSelected: _chooseMission),
        ),
        _ => const _WhitePanel(child: LoadingView(message: 'Preparando el código…')),
      };
    }
    return _QrDisplay(
      issued: issued,
      age: _age.elapsed,
      refreshing: _loading,
      refreshFailed: _refreshFailed,
      expired: _expired,
      onRetry: _fetch,
    );
  }
}

class _WhitePanel extends StatelessWidget {
  const _WhitePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radius)),
        child: child,
      ),
    );
  }
}

class _MissionChooser extends StatelessWidget {
  const _MissionChooser({required this.options, required this.onSelected});

  final List<MissionOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hay varias misiones activas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('¿De cuál quieres mostrar el código?'),
          const SizedBox(height: AppSpacing.md),
          for (final option in options) ...[
            FilledButton(onPressed: () => onSelected(option.id), child: Text(option.name)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _QrDisplay extends StatelessWidget {
  const _QrDisplay({
    required this.issued,
    required this.age,
    required this.refreshing,
    required this.refreshFailed,
    required this.expired,
    required this.onRetry,
  });

  final QrTokenIssued issued;
  final Duration age;
  final bool refreshing;
  final bool refreshFailed;
  final bool expired;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final secondsToRefresh = (issued.refreshAfter - age).inSeconds.clamp(0, 999);
    final progress = issued.refreshAfter.inMilliseconds == 0
        ? 0.0
        : (1 - age.inMilliseconds / issued.refreshAfter.inMilliseconds).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.biggest.shortestSide - 80).clamp(200.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Text(
                    issued.missionName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Pide a los misioneros que abran la app y toquen "Escanear sello".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    label: 'Código QR de la misión ${issued.missionName}',
                    image: true,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        border: Border.all(color: AppColors.gold, width: 4),
                      ),
                      child: Opacity(
                        opacity: expired ? 0.15 : 1,
                        child: QrImageView(
                          data: issued.token,
                          size: qrSize,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (expired)
                    _Notice(
                      icon: Icons.timer_off_rounded,
                      text: 'El código venció porque no hay conexión.',
                      action: FilledButton.icon(
                        onPressed: refreshing ? null : onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Intentar de nuevo'),
                      ),
                    )
                  else ...[
                    Text(
                      refreshing ? 'Renovando el código…' : 'El código se renueva solo en $secondsToRefresh s',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: refreshing ? null : progress,
                        minHeight: 10,
                        color: AppColors.amber,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    if (refreshFailed) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _Notice(
                        icon: Icons.wifi_off_rounded,
                        text: 'Sin conexión: seguimos intentando renovar el código.',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.warning, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 17, color: AppColors.textPrimary)),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
        ],
      ),
    );
  }
}
