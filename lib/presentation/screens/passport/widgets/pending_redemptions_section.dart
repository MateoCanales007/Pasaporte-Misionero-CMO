import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/models/pending_redemption.dart';
import '../../../providers/pending_redemptions_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/dialogs.dart';

/// Escaneos guardados sin conexión. Nunca se muestran como sellos confirmados.
class PendingRedemptionsSection extends ConsumerWidget {
  const PendingRedemptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingRedemptionsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Por validar', icon: Icons.cloud_upload_rounded),
        for (final item in items) ...[_PendingCard(item: item), const SizedBox(height: AppSpacing.sm)],
      ],
    );
  }
}

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.item});

  final PendingRedemption item;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    final summary = await ref.read(pendingRedemptionsProvider.notifier).retry();
    if (!mounted) return;
    setState(() => _busy = false);
    if (summary == null) return;
    if (summary.confirmed.isNotEmpty) {
      showAppSnackBar(context, '¡Sello confirmado!', type: SnackType.success);
    } else if (summary.stillPending > 0) {
      showAppSnackBar(context, 'Todavía no hay conexión. Lo intentaremos de nuevo automáticamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final failed = item.status == SyncStatus.failed;
    return InfoBanner(
      icon: failed ? Icons.error_rounded : Icons.hourglass_top_rounded,
      color: failed ? AppColors.error : AppColors.warning,
      background: failed ? AppColors.errorSurface : AppColors.warningSurface,
      title: failed ? 'No se pudo validar' : 'Pendiente de validación',
      message: failed
          ? (item.failureMessage ?? 'Vuelve a escanear el código QR.')
          : 'Escaneaste un código sin conexión. Se enviará automáticamente cuando vuelva el internet. '
                'Si el código vence antes, tendrás que volver a escanearlo.',
      action: failed
          ? OutlinedButton(
              onPressed: () => ref.read(pendingRedemptionsProvider.notifier).dismiss(item.id),
              child: const Text('Entendido'),
            )
          : FilledButton.icon(
              onPressed: _busy ? null : _retry,
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Enviar ahora'),
            ),
    );
  }
}
