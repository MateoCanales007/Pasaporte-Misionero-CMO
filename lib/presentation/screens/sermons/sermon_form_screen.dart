import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../core/utils/url_utils.dart';
import '../../../domain/models/sermon.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/image_picker_button.dart';
import '../../widgets/state_views.dart';
import 'sermon_card.dart';

enum _MetadataState { idle, loading, ready, failed, rejected }

/// Crear o editar una prédica (solo administradores). Al pegar el enlace se
/// obtienen título, plataforma y miniatura mediante Cloud Functions.
class SermonFormScreen extends ConsumerStatefulWidget {
  const SermonFormScreen({super.key, this.initial, this.metadataDebounce = const Duration(milliseconds: 700)});

  final Sermon? initial;
  final Duration metadataDebounce;

  @override
  ConsumerState<SermonFormScreen> createState() => _SermonFormScreenState();
}

class _SermonFormScreenState extends ConsumerState<SermonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final String _sermonId;

  Timer? _debounce;
  int _metadataRequest = 0;
  _MetadataState _metadataState = _MetadataState.idle;
  String? _metadataMessage;
  String? _metadataUrl;

  VideoPlatform _platform = VideoPlatform.other;
  String _domain = '';
  String? _externalVideoId;
  String _thumbnailUrl = '';
  String _coverImageUrl = '';
  String? _coverStoragePath;
  late DateTime _publishedAt;
  bool _active = true;

  bool _titleEditedByHand = false;
  bool _dirty = false;
  bool _saving = false;
  bool _uploading = false;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _sermonId = initial?.id ?? ref.read(sermonRepositoryProvider).newSermonId();
    _urlController = TextEditingController(text: initial?.sourceUrl ?? '');
    _titleController = TextEditingController(text: initial?.title ?? '');
    _publishedAt = initial?.publishedAt ?? ref.read(clockProvider)();
    if (initial != null) {
      _platform = initial.platform;
      _domain = initial.domain;
      _externalVideoId = initial.externalVideoId;
      _thumbnailUrl = initial.thumbnailUrl;
      _coverImageUrl = initial.coverImageUrl;
      _coverStoragePath = initial.coverStoragePath;
      _active = initial.active;
      _metadataUrl = initial.sourceUrl;
      _metadataState = _MetadataState.ready;
      _titleEditedByHand = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _onUrlChanged(String value) {
    _markDirty();
    _debounce?.cancel();
    final url = value.trim();
    if (url == _metadataUrl) return;
    if (url.isEmpty) {
      setState(() => _metadataState = _MetadataState.idle);
      return;
    }
    if (!UrlUtils.isSafeHttpsUrl(url)) {
      setState(() {
        _metadataState = _MetadataState.rejected;
        _metadataMessage = 'Pega un enlace completo que empiece con https://';
      });
      return;
    }
    setState(() => _metadataState = _MetadataState.loading);
    _debounce = Timer(widget.metadataDebounce, () => _fetchMetadata(url));
  }

  Future<void> _fetchMetadata(String url) async {
    final request = ++_metadataRequest;
    try {
      final result = await ref.read(sermonRepositoryProvider).fetchMetadata(url);
      if (!mounted || request != _metadataRequest) return;
      setState(() {
        switch (result) {
          case VideoUrlRejected(:final reason):
            _metadataState = _MetadataState.rejected;
            _metadataMessage = reason;
          case VideoMetadataFound(:final metadata):
            _metadataState = _MetadataState.ready;
            _metadataUrl = url;
            _platform = metadata.platform;
            _domain = metadata.domain;
            _externalVideoId = metadata.externalVideoId;
            _thumbnailUrl = metadata.thumbnailUrl ?? '';
            if (metadata.title != null && (!_titleEditedByHand || _titleController.text.trim().isEmpty)) {
              _titleController.text = metadata.title!;
              _titleEditedByHand = false;
            }
            _metadataMessage = metadata.title == null
                ? 'No pudimos obtener el título automáticamente. Escríbelo abajo.'
                : null;
        }
      });
    } catch (error) {
      if (!mounted || request != _metadataRequest) return;
      setState(() {
        _metadataState = _MetadataState.failed;
        _metadataMessage = '${friendlyErrorMessage(error)} Puedes escribir el título a mano.';
      });
    }
  }

  Future<void> _uploadCover() async {
    final picked = await pickImageForUpload(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await ref
          .read(sermonRepositoryProvider)
          .uploadCover(_sermonId, picked.bytes, picked.contentType);
      if (!mounted) return;
      setState(() {
        _coverImageUrl = uploaded.downloadUrl;
        _coverStoragePath = uploaded.storagePath;
        _dirty = true;
      });
      showAppSnackBar(context, 'Portada subida.', type: SnackType.success);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate() async {
    final wall = BusinessTime.toWallClock(_publishedAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(wall.year, wall.month, wall.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Fecha de publicación',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null) return;
    setState(() {
      _publishedAt = BusinessTime.fromWallClock(picked.year, picked.month, picked.day, 12);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final url = _urlController.text.trim();
    if (_metadataState == _MetadataState.loading) {
      showAppSnackBar(context, 'Espera un momento: estamos revisando el enlace.');
      return;
    }
    if (_metadataState == _MetadataState.rejected) {
      showAppSnackBar(context, _metadataMessage ?? 'El enlace no es válido.', type: SnackType.error);
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final hasMetadataForUrl = _metadataUrl == url;
    setState(() => _saving = true);
    try {
      await ref
          .read(sermonRepositoryProvider)
          .save(
            SermonDraft(
              id: _sermonId,
              isNew: _isNew,
              sourceUrl: url,
              title: _titleController.text,
              platform: hasMetadataForUrl ? _platform : VideoPlatform.other,
              domain: hasMetadataForUrl ? _domain : UrlUtils.domainOf(url),
              externalVideoId: hasMetadataForUrl ? _externalVideoId : null,
              thumbnailUrl: hasMetadataForUrl ? _thumbnailUrl : '',
              coverImageUrl: _coverImageUrl,
              coverStoragePath: _coverStoragePath,
              publishedAt: _publishedAt,
              active: _active,
            ),
            editorUid: uid,
          );
      if (!mounted) return;
      _dirty = false;
      showAppSnackBar(context, _isNew ? 'Prédica guardada.' : 'Cambios guardados.', type: SnackType.success);
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
    final title = _isNew ? 'Nueva prédica' : 'Editar prédica';
    if (!ref.watch(currentRoleProvider).isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const ErrorView(error: PermissionDeniedException('Solo los administradores pueden publicar prédicas.')),
      );
    }
    final theme = Theme.of(context);
    final previewImage = _coverImageUrl.isNotEmpty ? _coverImageUrl : _thumbnailUrl;

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
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('Enlace del video', icon: Icons.link_rounded),
                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        onChanged: _onUrlChanged,
                        decoration: const InputDecoration(
                          labelText: 'Pega aquí el enlace',
                          hintText: 'https://www.youtube.com/watch?v=…',
                          prefixIcon: Icon(Icons.link_rounded, color: AppColors.navy),
                        ),
                        validator: (v) => UrlUtils.isSafeHttpsUrl(v) ? null : 'Pega un enlace que empiece con https://',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _MetadataStatus(
                        state: _metadataState,
                        message: _metadataMessage,
                        platform: _platform,
                        domain: _domain,
                      ),
                      const SectionTitle('Título', icon: Icons.title_rounded),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 200,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          _titleEditedByHand = true;
                          _markDirty();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Título de la prédica',
                          helperText: 'Se completa solo con el título del video. Puedes corregirlo.',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el título' : null,
                      ),
                      const SectionTitle('Portada', icon: Icons.image_rounded),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: AppNetworkImage(url: previewImage, fallbackIcon: Icons.ondemand_video_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _coverImageUrl.isNotEmpty
                            ? 'Usando tu portada personalizada.'
                            : (_thumbnailUrl.isNotEmpty
                                  ? 'Usando la miniatura del video.'
                                  : 'Sin portada: puedes subir una imagen.'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _uploading || _saving ? null : _uploadCover,
                        icon: _uploading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                            : const Icon(Icons.upload_rounded),
                        label: Text(_uploading ? 'Subiendo…' : 'Subir portada propia'),
                      ),
                      if (_coverImageUrl.isNotEmpty && _thumbnailUrl.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _coverImageUrl = '';
                            _coverStoragePath = null;
                            _dirty = true;
                          }),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Usar la miniatura del video'),
                        ),
                      ],
                      const SectionTitle('Publicación', icon: Icons.event_rounded),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_rounded, size: 30),
                          title: const Text('Fecha de publicación'),
                          subtitle: Text(BusinessTime.formatLongDate(_publishedAt)),
                          trailing: const Icon(Icons.edit_calendar_rounded),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        child: SwitchListTile(
                          value: _active,
                          onChanged: (value) => setState(() {
                            _active = value;
                            _dirty = true;
                          }),
                          title: const Text('Visible para todos'),
                          subtitle: const Text('Si lo apagas, solo los administradores la verán.'),
                        ),
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
                        label: Text(_saving ? 'Guardando…' : 'Guardar prédica'),
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
}

class _MetadataStatus extends StatelessWidget {
  const _MetadataStatus({required this.state, required this.message, required this.platform, required this.domain});

  final _MetadataState state;
  final String? message;
  final VideoPlatform platform;
  final String domain;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _MetadataState.idle => const SizedBox.shrink(),
      _MetadataState.loading => const Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: AppSpacing.md),
          Expanded(child: Text('Revisando el enlace…')),
        ],
      ),
      _MetadataState.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              platformIcon(platform),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(domain.isEmpty ? platform.label : '${platform.label} · $domain')),
            ],
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(message!, style: const TextStyle(color: AppColors.warning, fontSize: 16)),
            ),
        ],
      ),
      _MetadataState.failed => Text(message ?? '', style: const TextStyle(color: AppColors.warning, fontSize: 16)),
      _MetadataState.rejected => Text(message ?? '', style: const TextStyle(color: AppColors.error, fontSize: 16)),
    };
  }
}
