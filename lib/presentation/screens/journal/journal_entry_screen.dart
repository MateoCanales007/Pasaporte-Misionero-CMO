import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/journal_entry.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';

/// Escribir o editar una reflexión. Se guarda aunque no haya conexión: la
/// lista muestra "Pendiente de guardar" hasta sincronizar.
class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({super.key, this.entry, this.missionId, this.missionName});

  final JournalEntry? entry;
  final String? missionId;
  final String? missionName;

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: widget.entry?.text ?? '');
  late final String _initialText = widget.entry?.text ?? '';

  bool get _dirty => _controller.text.trim() != _initialText.trim();

  String? get _missionName => widget.entry?.missionName ?? widget.missionName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final future = ref
        .read(journalRepositoryProvider)
        .save(
          uid,
          entryId: widget.entry?.id,
          text: _controller.text,
          missionId: widget.entry?.missionId ?? widget.missionId,
          missionName: _missionName,
        );
    // No se espera al servidor: sin conexión queda pendiente y se sincroniza solo.
    unawaited(
      future.catchError((Object error) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          buildAppSnackBar('No se pudo guardar tu reflexión: ${friendlyErrorMessage(error)}', type: SnackType.error),
        );
      }),
    );
    showAppSnackBar(context, 'Reflexión guardada.', type: SnackType.success);
    _controller.text = _initialText;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    final uid = ref.read(currentUidProvider);
    if (entry == null || uid == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar esta reflexión?',
      message: 'Se borrará de tu diario para siempre.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    unawaited(ref.read(journalRepositoryProvider).delete(uid, entry.id).catchError((Object _) {}));
    showAppSnackBar(context, 'Reflexión eliminada.', type: SnackType.success);
    _controller.text = _initialText;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          _controller.text = _initialText;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(isNew ? 'Nueva reflexión' : 'Mi reflexión')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hoja de cuaderno: fecha, misión y el texto de la reflexión.
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF7),
                          borderRadius: BorderRadius.circular(AppSpacing.radius),
                          border: Border.all(color: AppColors.yellow, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: const BoxDecoration(
                                color: AppColors.yellowSoft,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radius - 2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_stories_rounded, color: AppColors.orangeDark),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          BusinessTime.formatLongDate(widget.entry?.createdAt ?? DateTime.now()),
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_missionName != null) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    StatusChip.info('Misión: $_missionName', icon: Icons.flag_rounded),
                                  ],
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                              child: TextFormField(
                                controller: _controller,
                                minLines: 10,
                                maxLines: 24,
                                maxLength: JournalEntry.maxLength,
                                textCapitalization: TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 19, height: 1.6, color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: '¿Qué te habló Dios hoy? Escribe tu reflexión u oración…',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Escribe algo antes de guardar' : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text('Solo tú puedes leer tu diario.')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar'),
                      ),
                      if (!isNew) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Eliminar reflexión'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
