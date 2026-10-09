import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/qr_models.dart';

/// Resultado de un escaneo: respuesta del servidor o error inesperado.
class ScanOutcome {
  const ScanOutcome.result(RedemptionResult this.result) : error = null;

  const ScanOutcome.error(Object this.error) : result = null;

  final RedemptionResult? result;
  final Object? error;
}

class _ResultCopy {
  const _ResultCopy({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.canScanAgain = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool canScanAgain;
}

_ResultCopy _copyFor(ScanOutcome outcome) {
  final result = outcome.result;
  if (result == null) {
    return _ResultCopy(
      icon: Icons.error_rounded,
      color: AppColors.error,
      title: 'No pudimos validar tu sello',
      message: friendlyErrorMessage(outcome.error!),
      canScanAgain: true,
    );
  }
  return switch (result) {
    RedemptionConfirmed(:final missionName) => _ResultCopy(
      icon: Icons.verified_rounded,
      color: AppColors.success,
      title: '¡Sello obtenido!',
      message: 'El sello de "$missionName" ya está en tu pasaporte.',
    ),
    RedemptionAlreadyRedeemed(:final missionName) => _ResultCopy(
      icon: Icons.task_alt_rounded,
      color: AppColors.navy,
      title: 'Ya tienes este sello',
      message: 'El sello de "$missionName" ya estaba en tu pasaporte. ¡Gracias por participar!',
    ),
    RedemptionExpired() => const _ResultCopy(
      icon: Icons.timer_off_rounded,
      color: AppColors.warning,
      title: 'El código venció',
      message: 'Los códigos cambian cada minuto. Vuelve a escanear el código que se muestra ahora.',
      canScanAgain: true,
    ),
    RedemptionInvalid(:final isLegacyCode) => _ResultCopy(
      icon: Icons.qr_code_2_rounded,
      color: AppColors.error,
      title: 'Código no válido',
      message: isLegacyCode
          ? 'Este código QR es antiguo y ya no se usa. Pide al encargado que muestre el código nuevo.'
          : 'Este código no es de una misión del CMO. Escanea el código que muestra el encargado.',
      canScanAgain: true,
    ),
    RedemptionNotFound() => const _ResultCopy(
      icon: Icons.search_off_rounded,
      color: AppColors.error,
      title: 'Misión no encontrada',
      message: 'Este código ya no corresponde a ninguna misión.',
      canScanAgain: true,
    ),
    RedemptionInactive(:final missionName) => _ResultCopy(
      icon: Icons.pause_circle_rounded,
      color: AppColors.warning,
      title: 'Misión no activa',
      message: 'La misión "$missionName" no está activa en este momento.',
    ),
    RedemptionOutsideSchedule(:final missionName) => _ResultCopy(
      icon: Icons.schedule_rounded,
      color: AppColors.warning,
      title: 'Fuera de horario',
      message: 'El sello de "$missionName" solo se puede obtener durante el horario de la misión.',
    ),
    RedemptionQueued() => const _ResultCopy(
      icon: Icons.cloud_off_rounded,
      color: AppColors.warning,
      title: 'Sin conexión: escaneo guardado',
      message:
          'Tu escaneo quedó pendiente de validación. Lo enviaremos en cuanto vuelva el internet. '
          'Todavía no es un sello confirmado. Si el código vence antes, tendrás que escanearlo de nuevo.',
      canScanAgain: true,
    ),
  };
}

/// Pantalla completa, con ícono, texto grande y un botón claro.
class RedemptionResultView extends StatelessWidget {
  const RedemptionResultView({super.key, required this.outcome, required this.onScanAgain, required this.onClose});

  final ScanOutcome outcome;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(outcome);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(copy.icon, size: 110, color: copy.color),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(color: copy.color),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      copy.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (copy.canScanAgain) ...[
                      FilledButton.icon(
                        onPressed: onScanAgain,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Escanear de nuevo'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(onPressed: onClose, child: const Text('Volver a mi pasaporte')),
                    ] else
                      FilledButton.icon(
                        onPressed: onClose,
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Volver a mi pasaporte'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
