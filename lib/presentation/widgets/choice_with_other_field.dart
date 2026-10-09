import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class ChoiceOption {
  const ChoiceOption(this.value, this.label);

  final String value;
  final String label;
}

/// Lista desplegable con opción "Otra" que muestra un campo de texto libre.
/// El valor reportado es el `value` de la opción o el texto escrito.
class ChoiceWithOtherField extends StatefulWidget {
  const ChoiceWithOtherField({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.initialValue = '',
    this.otherLabel = 'Otra',
    this.otherFieldLabel = 'Escríbela aquí',
    this.maxLength = 60,
  });

  final String label;
  final IconData icon;
  final List<ChoiceOption> options;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final String otherLabel;
  final String otherFieldLabel;
  final int maxLength;

  @override
  State<ChoiceWithOtherField> createState() => _ChoiceWithOtherFieldState();
}

class _ChoiceWithOtherFieldState extends State<ChoiceWithOtherField> {
  static const _other = '__other__';

  late final TextEditingController _otherController;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue.trim();
    final matches = widget.options.any((o) => o.value == initial);
    _selected = initial.isEmpty ? null : (matches ? initial : _other);
    _otherController = TextEditingController(text: matches ? '' : initial);
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_selected == _other ? _otherController.text.trim() : (_selected ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final option in widget.options)
        DropdownMenuItem(
          value: option.value,
          child: Text(option.label, overflow: TextOverflow.ellipsis),
        ),
      DropdownMenuItem(value: _other, child: Text(widget.otherLabel)),
    ];
    final selectedIsKnown = _selected == null || _selected == _other || widget.options.any((o) => o.value == _selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedIsKnown ? _selected : _other,
          isExpanded: true,
          itemHeight: AppSpacing.touchTarget,
          style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon, color: AppColors.navy),
          ),
          items: items,
          validator: (value) => value == null ? 'Elige una opción' : null,
          onChanged: (value) {
            setState(() => _selected = value);
            _emit();
          },
        ),
        if (_selected == _other) ...[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _otherController,
            maxLength: widget.maxLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.otherFieldLabel,
              prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.navy),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Escribe un valor' : null,
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}

/// Nacionalidades frecuentes en la congregación.
const nationalityOptions = [
  ChoiceOption('Salvadoreña', 'Salvadoreña'),
  ChoiceOption('Guatemalteca', 'Guatemalteca'),
  ChoiceOption('Hondureña', 'Hondureña'),
  ChoiceOption('Nicaragüense', 'Nicaragüense'),
  ChoiceOption('Costarricense', 'Costarricense'),
  ChoiceOption('Mexicana', 'Mexicana'),
  ChoiceOption('Colombiana', 'Colombiana'),
  ChoiceOption('Estadounidense', 'Estadounidense'),
];
