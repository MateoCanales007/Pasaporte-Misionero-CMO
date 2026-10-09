import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/testimonial.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';

class TestimonialFormScreen extends ConsumerStatefulWidget {
  const TestimonialFormScreen({super.key});

  @override
  ConsumerState<TestimonialFormScreen> createState() => _TestimonialFormScreenState();
}

class _TestimonialFormScreenState extends ConsumerState<TestimonialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final name = ref.read(currentUserProvider).value?.fullName ?? 'Misionero';
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(testimonialRepositoryProvider).submit(uid: uid, displayName: name, text: _controller.text);
      if (!mounted) return;
      showAppSnackBar(
        context,
        '¡Gracias! Tu testimonio se publicará cuando un administrador lo revise.',
        type: SnackType.success,
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _controller.text.trim().isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          _controller.clear();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Compartir testimonio')),
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
                      const InfoBanner(
                        icon: Icons.info_rounded,
                        message:
                            'Cuéntanos lo que Dios ha hecho en tu vida. Un administrador lo revisará antes de '
                            'publicarlo con tu nombre.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _controller,
                        minLines: 6,
                        maxLines: 12,
                        maxLength: Testimonial.maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Tu testimonio', alignLabelWithHint: true),
                        validator: (v) => (v == null || v.trim().length < Testimonial.minLength)
                            ? 'Escribe al menos ${Testimonial.minLength} letras'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Enviando…' : 'Enviar testimonio'),
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
