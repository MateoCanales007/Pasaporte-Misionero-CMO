import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/url_utils.dart';
import '../../../domain/models/mission.dart';
import '../../../domain/use_cases/validate_mission_schedules.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/image_picker_button.dart';
import '../../widgets/map_view.dart';
import '../../widgets/state_views.dart';
import 'mission_card.dart';
import 'widgets/place_search_field.dart';
import 'widgets/schedule_editor.dart';

/// Crear, editar o duplicar una misión (solo administradores). La escritura
/// pasa por la Cloud Function `saveMission`, que vuelve a validar todo.
class MissionFormScreen extends ConsumerStatefulWidget {
  const MissionFormScreen({super.key, this.initial, this.duplicate = false});

  final Mission? initial;

  /// Crea un borrador nuevo a partir de [initial].
  final bool duplicate;

  @override
  ConsumerState<MissionFormScreen> createState() => _MissionFormScreenState();
}

class _MissionFormScreenState extends ConsumerState<MissionFormScreen> {
  static final _isoPattern = RegExp(r'^[A-Z]{2,6}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _isoController;
  late final TextEditingController _imageController;

  GeoLocation? _location;
  String? _placeId;
  late List<MissionSchedule> _schedules;
  late MissionStatus _status;
  bool _dirty = false;
  bool _saving = false;
  bool _uploading = false;
  bool _submitted = false;

  bool get _isEditing => widget.initial != null && !widget.duplicate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final now = ref.read(clockProvider)();
    _nameController = TextEditingController(
      text: initial == null ? '' : (widget.duplicate ? '${initial.name} (copia)' : initial.name),
    );
    _isoController = TextEditingController(text: initial?.isoCode ?? '');
    _imageController = TextEditingController(text: initial?.imageUrl ?? '');
    _location = initial?.location;
    _placeId = initial?.placeId;
    if (initial != null) {
      _schedules = initial.sortedSchedules;
    } else {
      final start = defaultScheduleStart(now);
      _schedules = [MissionSchedule(start: start, end: start.add(const Duration(hours: 3)))];
    }
    _status = widget.duplicate ? MissionStatus.draft : (initial?.status ?? MissionStatus.active);
    for (final controller in [_nameController, _isoController, _imageController]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isoController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  List<ScheduleIssue> get _scheduleIssues =>
      ValidateMissionSchedules.call(_schedules, requireAtLeastOne: _status == MissionStatus.active);

  Mission _previewMission() => Mission(
    id: widget.initial?.id ?? 'preview',
    name: _nameController.text.trim().isEmpty ? 'Nombre de la misión' : _nameController.text.trim(),
    isoCode: _isoController.text.trim().isEmpty ? 'ISO' : _isoController.text.trim(),
    status: _status,
    imageUrl: UrlUtils.isSafeHttpsUrl(_imageController.text) ? _imageController.text.trim() : '',
    location: _location,
    schedules: _schedules,
  );

  Future<void> _uploadImage() async {
    final picked = await pickImageForUpload(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await ref.read(missionRepositoryProvider).uploadMissionImage(picked.bytes, picked.contentType);
      _imageController.text = uploaded.downloadUrl;
      if (mounted) showAppSnackBar(context, 'Imagen subida.', type: SnackType.success);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _location == null || _scheduleIssues.isNotEmpty) {
      showAppSnackBar(context, 'Revisa los campos marcados en rojo.', type: SnackType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(missionRepositoryProvider)
          .saveMission(
            MissionDraft(
              id: _isEditing ? widget.initial!.id : null,
              name: _nameController.text,
              isoCode: _isoController.text,
              imageUrl: _imageController.text,
              location: _location!,
              placeId: _placeId,
              schedules: _schedules,
              status: _status,
            ),
          );
      if (!mounted) return;
      showAppSnackBar(context, _isEditing ? 'Misión actualizada.' : 'Misión creada.', type: SnackType.success);
      _dirty = false;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
      setState(() => _saving = false);
    }
  }

  Future<void> _handlePop() async {
    if (await confirmDiscardChanges(context) && mounted) {
      _dirty = false;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final title = _isEditing ? 'Editar misión' : (widget.duplicate ? 'Duplicar misión' : 'Nueva misión');
    if (!role.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorView(
          error: const PermissionDeniedException('Solo los administradores pueden crear o editar misiones.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final issues = _scheduleIssues;
    final mapBuilder = ref.watch(mapViewBuilderProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('Datos de la misión', icon: Icons.flag_rounded),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Nombre de la misión', hintText: 'Ej: Guatemala'),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'Escribe el nombre (mínimo 2 letras)' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _isoController,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')), _UpperCaseFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Código del país (ISO)',
                          hintText: 'Ej: GT, SLV, HND',
                          helperText: 'De 2 a 6 letras.',
                        ),
                        validator: (v) => _isoPattern.hasMatch(v?.trim() ?? '') ? null : 'Escribe de 2 a 6 letras',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _imageController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Imagen (enlace https)',
                          helperText: 'Pega un enlace o sube una imagen desde tu dispositivo.',
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty || UrlUtils.isSafeHttpsUrl(value)) return null;
                          return 'El enlace debe empezar con https://';
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _uploading || _saving ? null : _uploadImage,
                        icon: _uploading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                            : const Icon(Icons.upload_rounded),
                        label: Text(_uploading ? 'Subiendo…' : 'Subir imagen'),
                      ),
                      const SectionTitle('Ubicación', icon: Icons.place_rounded),
                      PlaceSearchField(
                        onSelected: (location, placeId) => _update(() {
                          _location = location;
                          _placeId = placeId;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('O toca el mapa para marcar el lugar exacto:', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        child: SizedBox(
                          height: 280,
                          child: mapBuilder(
                            marker: _location,
                            center: _location ?? defaultMapCenter,
                            zoom: 8,
                            onTap: (location) => _update(() {
                              _location = location;
                              _placeId = null;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_location != null)
                        StatusChip.success(
                          'Ubicación elegida: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}',
                          icon: Icons.place_rounded,
                        )
                      else if (_submitted)
                        const Text('Elige una ubicación.', style: TextStyle(color: AppColors.error, fontSize: 16)),
                      const SectionTitle('Horarios', icon: Icons.schedule_rounded),
                      ScheduleEditor(
                        schedules: _schedules,
                        issues: issues,
                        now: now,
                        onChanged: (list) => _update(() => _schedules = list),
                      ),
                      const SectionTitle('Estado', icon: Icons.toggle_on_rounded),
                      SegmentedButton<MissionStatus>(
                        segments: const [
                          ButtonSegment(
                            value: MissionStatus.draft,
                            label: Text('Borrador'),
                            icon: Icon(Icons.edit_note_rounded),
                          ),
                          ButtonSegment(
                            value: MissionStatus.active,
                            label: Text('Activa'),
                            icon: Icon(Icons.check_circle_rounded),
                          ),
                          ButtonSegment(
                            value: MissionStatus.inactive,
                            label: Text('Inactiva'),
                            icon: Icon(Icons.pause_circle_rounded),
                          ),
                        ],
                        selected: {_status},
                        onSelectionChanged: (value) => _update(() => _status = value.first),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_statusHelp(_status), style: theme.textTheme.bodyMedium),
                      const SectionTitle('Vista previa', icon: Icons.visibility_rounded),
                      Text('Así verán los misioneros esta misión:', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.sm),
                      IgnorePointer(
                        child: MissionCard(mission: _previewMission(), now: now),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: _saving || _uploading ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Guardando…' : 'Guardar misión'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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

  static String _statusHelp(MissionStatus status) => switch (status) {
    MissionStatus.draft => 'Borrador: solo la ven los administradores. Nadie puede obtener el sello.',
    MissionStatus.active => 'Activa: visible para todos; el QR funciona durante los horarios.',
    MissionStatus.inactive => 'Inactiva: visible, pero nadie puede obtener el sello.',
  };
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
