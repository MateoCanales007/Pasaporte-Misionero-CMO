import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../core/utils/url_utils.dart';
import '../../../domain/models/sermon.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';

/// Ícono de la plataforma de video (marca o enlace genérico).
Widget platformIcon(VideoPlatform platform, {double size = 22}) {
  final color = platformColor(platform);
  return switch (platform) {
    VideoPlatform.youtube => FaIcon(FontAwesomeIcons.youtube, size: size, color: color),
    VideoPlatform.vimeo => FaIcon(FontAwesomeIcons.vimeoV, size: size, color: color),
    VideoPlatform.facebook => FaIcon(FontAwesomeIcons.facebook, size: size, color: color),
    VideoPlatform.other => Icon(Icons.link_rounded, size: size, color: color),
  };
}

Color platformColor(VideoPlatform platform) => switch (platform) {
  VideoPlatform.youtube => const Color(0xFFC4302B),
  VideoPlatform.vimeo => const Color(0xFF1A7FA8),
  VideoPlatform.facebook => const Color(0xFF1877F2),
  VideoPlatform.other => AppColors.navy,
};

/// Abre el video en la app de la plataforma (Android) o en otra pestaña (web).
Future<void> openSermon(BuildContext context, Sermon sermon) async {
  if (!UrlUtils.isSafeHttpsUrl(sermon.sourceUrl)) {
    showAppSnackBar(context, 'El enlace de esta prédica no es válido.', type: SnackType.error);
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(sermon.sourceUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showAppSnackBar(context, 'No se pudo abrir el video. Inténtalo de nuevo.', type: SnackType.error);
  }
}

class SermonCard extends StatelessWidget {
  const SermonCard({super.key, required this.sermon, this.adminActions});

  final Sermon sermon;

  /// Acciones visibles solo para administradores.
  final Widget? adminActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = sermon.domain.isNotEmpty ? sermon.domain : UrlUtils.domainOf(sermon.sourceUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => openSermon(context, sermon),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppNetworkImage(
                    url: sermon.displayImageUrl,
                    fallbackIcon: Icons.ondemand_video_rounded,
                    semanticLabel: 'Portada de ${sermon.title}',
                  ),
                ),
                // Ícono pequeño en la esquina para no tapar la portada.
                const Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!sermon.active || sermon.deleted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: sermon.deleted
                          ? StatusChip.error('En la papelera', icon: Icons.delete_rounded)
                          : StatusChip.neutral('Oculta para los misioneros', icon: Icons.visibility_off_rounded),
                    ),
                  ),
                // El título abre el video; sin subrayado.
                Semantics(
                  link: true,
                  hint: 'Abre el video',
                  child: InkWell(
                    onTap: () => openSermon(context, sermon),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(sermon.title, style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    platformIcon(sermon.platform, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        domain.isEmpty ? sermon.platform.label : '${sermon.platform.label} · $domain',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Publicada el ${BusinessTime.formatLongDate(sermon.publishedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (adminActions != null) ...[const SizedBox(height: AppSpacing.md), adminActions!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
