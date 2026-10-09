import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/app_user.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/choice_with_other_field.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import 'auth_screen.dart';

/// Último paso del registro: datos del pasaporte.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String _nationality = '';
  String _cellId = '';
  bool _communityVisible = true;
  bool _saving = false;
  bool _birthDateMissing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 40),
      firstDate: DateTime(1920),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Elige tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateMissing = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState!.validate();
    setState(() => _birthDateMissing = _birthDate == null);
    if (!formOk || _birthDate == null) return;

    final identity = ref.read(authIdentityProvider).value;
    if (identity == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .createPassport(
            identity.uid,
            identity.username,
            NewPassport(
              fullName: _nameController.text,
              dateOfBirth: DateTime.utc(_birthDate!.year, _birthDate!.month, _birthDate!.day, 12),
              nationality: _nationality,
              cellId: _cellId,
              communityVisible: _communityVisible,
            ),
          );
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cells = ref.watch(cellsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu pasaporte'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _logout,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ResponsiveCenter(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Último paso', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Escribe tus datos para crear tu pasaporte misionero.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_rounded, color: AppColors.navy),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Escribe tu nombre completo' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BirthDateField(date: _birthDate, missing: _birthDateMissing, onTap: _pickBirthDate),
                  const SizedBox(height: AppSpacing.lg),
                  ChoiceWithOtherField(
                    label: 'Nacionalidad',
                    icon: Icons.flag_rounded,
                    options: nationalityOptions,
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
                      label: 'Célula a la que perteneces',
                      icon: Icons.groups_rounded,
                      options: [for (final c in list) ChoiceOption(c.id, c.name)],
                      otherLabel: 'Otra / Aún no tengo',
                      otherFieldLabel: 'Nombre de la célula o escribe "Ninguna"',
                      maxLength: 80,
                      onChanged: (value) => _cellId = value,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: SwitchListTile(
                      value: _communityVisible,
                      onChanged: (value) => setState(() => _communityVisible = value),
                      title: const Text('Aparecer en Comunidad'),
                      subtitle: const Text(
                        'Otros misioneros verán tu nombre, tu célula y tus sellos. Puedes cambiarlo cuando quieras.',
                      ),
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
                        : const Icon(Icons.badge_rounded),
                    label: Text(_saving ? 'Creando…' : 'Crear mi pasaporte'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.date, required this.missing, required this.onTap});

  final DateTime? date;
  final bool missing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date == null ? 'Toca para elegir' : DateFormat("d 'de' MMMM 'de' y", 'es').format(date!);
    return Semantics(
      button: true,
      label: 'Fecha de nacimiento: $text',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            helperText: 'Es privada: nadie más la verá.',
            errorText: missing ? 'Elige tu fecha de nacimiento' : null,
            prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.navy),
            suffixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.navy),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 18, color: date == null ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
