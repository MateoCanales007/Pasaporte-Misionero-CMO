import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/app_user.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/choice_with_other_field.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(text: widget.user.fullName);
  late String _nationality = widget.user.nationality;
  late String _cellId = widget.user.cellId;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            widget.user.uid,
            ProfileUpdate(fullName: _nameController.text, nationality: _nationality, cellId: _cellId),
          );
      if (!mounted) return;
      _dirty = false;
      showAppSnackBar(context, 'Tus datos se guardaron.', type: SnackType.success);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = ref.watch(cellsProvider);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          _dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis datos')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_rounded, color: AppColors.navy),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Escribe tu nombre completo' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ChoiceWithOtherField(
                        label: 'Nacionalidad',
                        icon: Icons.flag_rounded,
                        options: nationalityOptions,
                        initialValue: widget.user.nationality,
                        otherFieldLabel: 'Escribe tu nacionalidad',
                        onChanged: (value) => _nationality = value,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      cells.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const InfoBanner(
                          icon: Icons.wifi_off_rounded,
                          message: 'No pudimos cargar la lista de células. Revisa tu conexión.',
                        ),
                        data: (list) => ChoiceWithOtherField(
                          label: 'Célula',
                          icon: Icons.groups_rounded,
                          options: [for (final c in list) ChoiceOption(c.id, c.name)],
                          initialValue: widget.user.cellId,
                          otherLabel: 'Otra / Aún no tengo',
                          otherFieldLabel: 'Nombre de la célula o "Ninguna"',
                          maxLength: 80,
                          onChanged: (value) => _cellId = value,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                      ),
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
