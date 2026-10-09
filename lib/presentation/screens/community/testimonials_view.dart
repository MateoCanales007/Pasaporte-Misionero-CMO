import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/testimonial.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import 'testimonial_form_screen.dart';

/// Testimonios: los aprobados son públicos; cada quien ve el estado de los
/// suyos; los administradores moderan aquí mismo.
class TestimonialsView extends ConsumerWidget {
  const TestimonialsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final pending = ref.watch(pendingTestimonialsProvider).value ?? const [];
    final mine = ref.watch(myTestimonialsProvider).value ?? const [];
    final approved = ref.watch(approvedTestimonialsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        ResponsiveCenter(
          child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestimonialFormScreen())),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Compartir mi testimonio'),
          ),
        ),
        if (isAdmin && pending.isNotEmpty) ...[
          const ResponsiveCenter(child: SectionTitle('Por revisar', icon: Icons.fact_check_rounded)),
          for (final t in pending)
            ResponsiveCenter(
              child: _TestimonialCard(
                testimonial: t,
                moderation: _ModerationButtons(testimonial: t),
              ),
            ),
        ],
        if (mine.isNotEmpty) ...[
          const ResponsiveCenter(child: SectionTitle('Mis testimonios', icon: Icons.person_rounded)),
          for (final t in mine)
            ResponsiveCenter(child: _TestimonialCard(testimonial: t, showStatus: true, canDelete: true)),
        ],
        const ResponsiveCenter(child: SectionTitle('Testimonios de la comunidad', icon: Icons.forum_rounded)),
        ResponsiveCenter(
          child: AsyncValueView<List<Testimonial>>(
            value: approved,
            onRetry: () => ref.invalidate(approvedTestimonialsProvider),
            isEmpty: (list) => list.isEmpty,
            empty: const EmptyView(
              icon: Icons.forum_outlined,
              title: 'Aún no hay testimonios publicados',
              message: '¡Sé el primero en compartir lo que Dios ha hecho!',
            ),
            data: (list) => Column(children: [for (final t in list) _TestimonialCard(testimonial: t)]),
          ),
        ),
      ],
    );
  }
}

class _TestimonialCard extends ConsumerWidget {
  const _TestimonialCard({required this.testimonial, this.showStatus = false, this.canDelete = false, this.moderation});

  final Testimonial testimonial;
  final bool showStatus;
  final bool canDelete;
  final Widget? moderation;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar tu testimonio?',
      message: 'Se borrará para siempre.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(testimonialRepositoryProvider).delete(testimonial.id);
      if (context.mounted) showAppSnackBar(context, 'Testimonio eliminado.', type: SnackType.success);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = testimonial.createdAt == null ? 'Enviando…' : BusinessTime.formatLongDate(testimonial.createdAt!);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_quote_rounded, color: AppColors.gold, size: 30),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(testimonial.displayName, style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(testimonial.text, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(date, style: theme.textTheme.bodySmall),
              if (showStatus) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: switch (testimonial.status) {
                    TestimonialStatus.pending => StatusChip.warning(testimonial.status.label),
                    TestimonialStatus.approved => StatusChip.success(testimonial.status.label),
                    TestimonialStatus.rejected => StatusChip.neutral(
                      testimonial.status.label,
                      icon: Icons.block_rounded,
                    ),
                  },
                ),
              ],
              if (canDelete) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _delete(context, ref),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
              if (moderation != null) ...[const SizedBox(height: AppSpacing.md), moderation!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModerationButtons extends ConsumerStatefulWidget {
  const _ModerationButtons({required this.testimonial});

  final Testimonial testimonial;

  @override
  ConsumerState<_ModerationButtons> createState() => _ModerationButtonsState();
}

class _ModerationButtonsState extends ConsumerState<_ModerationButtons> {
  bool _busy = false;

  Future<void> _moderate(TestimonialStatus status) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(testimonialRepositoryProvider).moderate(widget.testimonial.id, status, moderatorUid: uid);
      if (mounted) {
        showAppSnackBar(
          context,
          status == TestimonialStatus.approved ? 'Testimonio publicado.' : 'Testimonio rechazado.',
          type: SnackType.success,
        );
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _moderate(TestimonialStatus.approved),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aprobar'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _moderate(TestimonialStatus.rejected),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Rechazar'),
          ),
        ),
      ],
    );
  }
}
