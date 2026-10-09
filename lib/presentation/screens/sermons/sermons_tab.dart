import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/sermon.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import 'sermon_card.dart';
import 'sermon_form_screen.dart';

/// Prédicas para todos los roles. Los administradores gestionan desde aquí
/// mismo (sin panel aparte).
class SermonsTab extends ConsumerWidget {
  const SermonsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final sermons = ref.watch(sermonsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sermonsProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              child: PageHeader(
                title: 'Prédicas',
                subtitle: 'Mensajes para ver y escuchar cuando quieras.',
                trailing: isAdmin
                    ? FilledButton.icon(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SermonFormScreen())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar prédica'),
                      )
                    : null,
              ),
            ),
          ),
          sermons.when(
            skipLoadingOnReload: true,
            loading: () =>
                const SliverFillRemaining(hasScrollBody: false, child: LoadingView(message: 'Cargando prédicas…')),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(error: error, onRetry: () => ref.invalidate(sermonsProvider)),
            ),
            data: (list) {
              final visible = list.where((s) => !s.deleted).toList();
              final trash = list.where((s) => s.deleted).toList();
              if (visible.isEmpty && trash.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.video_library_outlined,
                    title: 'Aún no hay prédicas',
                    message: 'Cuando se publique una prédica aparecerá aquí.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList.list(
                  children: [
                    for (final sermon in visible) ...[
                      ResponsiveCenter(
                        child: SermonCard(
                          sermon: sermon,
                          adminActions: isAdmin ? _SermonAdminActions(sermon: sermon) : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (isAdmin && trash.isNotEmpty) ...[
                      const ResponsiveCenter(child: SectionTitle('Papelera', icon: Icons.delete_outline_rounded)),
                      for (final sermon in trash) ...[
                        ResponsiveCenter(
                          child: SermonCard(
                            sermon: sermon,
                            adminActions: _SermonAdminActions(sermon: sermon),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SermonAdminActions extends ConsumerStatefulWidget {
  const _SermonAdminActions({required this.sermon});

  final Sermon sermon;

  @override
  ConsumerState<_SermonAdminActions> createState() => _SermonAdminActionsState();
}

class _SermonAdminActionsState extends ConsumerState<_SermonAdminActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(String uid) action, String successMessage) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(uid);
      if (mounted) showAppSnackBar(context, successMessage, type: SnackType.success);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar la prédica?',
      message: 'Dejará de verse para los misioneros. Podrás recuperarla desde la Papelera.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    final repo = ref.read(sermonRepositoryProvider);
    await _run((uid) => repo.softDelete(widget.sermon.id, editorUid: uid), 'Prédica enviada a la papelera.');
  }

  @override
  Widget build(BuildContext context) {
    final sermon = widget.sermon;
    final repo = ref.read(sermonRepositoryProvider);
    if (sermon.deleted) {
      return OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _run((uid) => repo.restore(sermon.id, editorUid: uid), 'Prédica recuperada (oculta).'),
        icon: const Icon(Icons.restore_rounded),
        label: const Text('Recuperar'),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SermonFormScreen(initial: sermon))),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (uid) => repo.setActive(sermon.id, !sermon.active, editorUid: uid),
                  sermon.active ? 'Prédica ocultada.' : 'Prédica publicada.',
                ),
          icon: Icon(sermon.active ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          label: Text(sermon.active ? 'Ocultar' : 'Publicar'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Eliminar'),
        ),
      ],
    );
  }
}
