import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../widgets/dialogs.dart';

/// Descarga de la app para Android desde el sitio oficial (mismo enlace siempre,
/// con la versión más reciente) y opción de copiar el enlace para compartirlo.
class DownloadAppCard extends StatelessWidget {
  const DownloadAppCard({super.key});

  Future<void> _download(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppLinks.androidApk),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      opened = false;
    }
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      opened
          ? 'Descargando la app. Al terminar, ábrela desde las notificaciones para instalarla.'
          : 'No se pudo iniciar la descarga. Inténtalo de nuevo.',
      type: opened ? SnackType.info : SnackType.error,
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppLinks.androidApk));
    if (context.mounted) {
      showAppSnackBar(context, 'Enlace copiado. Puedes pegarlo en WhatsApp para compartirlo.', type: SnackType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.yellowSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.android_rounded, size: 34, color: AppColors.success),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('App para Android', style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Descarga siempre la versión más reciente. Si el teléfono lo pide, permite instalar apps de esta fuente.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => _download(context),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar la app'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _copyLink(context),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copiar enlace para compartir'),
            ),
          ],
        ),
      ),
    );
  }
}
