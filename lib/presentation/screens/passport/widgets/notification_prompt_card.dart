import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../providers/notification_status_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/dialogs.dart';

/// Invitación (una sola vez) a activar los avisos.
class NotificationPromptCard extends ConsumerWidget {
  const NotificationPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationStatusProvider).value;
    if (status == null || !status.shouldPrompt) return const SizedBox.shrink();
    final notifier = ref.read(notificationStatusProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: InfoBanner(
        icon: Icons.notifications_active_rounded,
        title: '¿Quieres recibir avisos?',
        message: 'Te avisaremos de nuevas misiones, prédicas y cuando se confirme tu sello.',
        action: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              onPressed: () async {
                final granted = await notifier.enable();
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  granted
                      ? 'Listo, recibirás avisos en este dispositivo.'
                      : 'No se activaron los avisos. Puedes hacerlo luego desde Perfil.',
                  type: granted ? SnackType.success : SnackType.info,
                );
              },
              child: const Text('Sí, activar avisos'),
            ),
            OutlinedButton(onPressed: notifier.dismissPrompt, child: const Text('Ahora no')),
          ],
        ),
      ),
    );
  }
}
