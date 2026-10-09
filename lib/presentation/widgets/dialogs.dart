import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';

enum SnackType { info, success, error }

void showAppSnackBar(BuildContext context, String message, {SnackType type = SnackType.info}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(buildAppSnackBar(message, type: type));
}

SnackBar buildAppSnackBar(String message, {SnackType type = SnackType.info}) {
  final (color, icon) = switch (type) {
    SnackType.success => (AppColors.success, Icons.check_circle_rounded),
    SnackType.error => (AppColors.error, Icons.error_rounded),
    SnackType.info => (AppColors.navy, Icons.info_rounded),
  };
  return SnackBar(
    backgroundColor: color,
    duration: const Duration(seconds: 5),
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

void showErrorSnackBar(BuildContext context, Object error) =>
    showAppSnackBar(context, friendlyErrorMessage(error), type: SnackType.error);

/// Pide confirmación con botones grandes y textos explícitos.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirmación estándar antes de descartar un formulario con cambios.
Future<bool> confirmDiscardChanges(BuildContext context) => showConfirmDialog(
  context,
  title: '¿Salir sin guardar?',
  message: 'Tienes cambios que no se han guardado. Si sales ahora se perderán.',
  confirmLabel: 'Salir sin guardar',
  cancelLabel: 'Seguir editando',
  destructive: true,
);
