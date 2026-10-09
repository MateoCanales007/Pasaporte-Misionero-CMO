import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Limita el ancho del contenido en pantallas grandes (web/tablet).
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = AppSpacing.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Encabezado de pestaña: título grande y una línea de explicación.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: theme.textTheme.headlineMedium)),
          const SizedBox(height: AppSpacing.xs),
          const BrandStripe(),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
          ],
          if (trailing != null) ...[const SizedBox(height: AppSpacing.md), trailing!],
        ],
      ),
    );
  }
}

/// Título de sección dentro de una página.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.orangeDark, size: 26),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de estado con color e ícono (no depende solo del color).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, required this.background, this.icon});

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  factory StatusChip.success(String label, {IconData icon = Icons.check_circle_rounded}) =>
      StatusChip(label: label, color: AppColors.success, background: AppColors.successSurface, icon: icon);

  factory StatusChip.warning(String label, {IconData icon = Icons.schedule_rounded}) =>
      StatusChip(label: label, color: AppColors.warning, background: AppColors.warningSurface, icon: icon);

  factory StatusChip.error(String label, {IconData icon = Icons.error_rounded}) =>
      StatusChip(label: label, color: AppColors.error, background: AppColors.errorSurface, icon: icon);

  factory StatusChip.neutral(String label, {IconData icon = Icons.info_rounded}) =>
      StatusChip(label: label, color: AppColors.neutral, background: AppColors.neutralSurface, icon: icon);

  factory StatusChip.info(String label, {IconData icon = Icons.info_rounded}) =>
      StatusChip(label: label, color: AppColors.navy, background: AppColors.surfaceTint, icon: icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar con iniciales y borde dorado.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.initials, this.radius = 28});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.gold,
        child: CircleAvatar(
          radius: radius - 3,
          backgroundColor: AppColors.surfaceTint,
          child: Text(
            initials,
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: radius * 0.65),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta informativa con ícono (avisos, ayuda, estados).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.color = AppColors.navy,
    this.background = AppColors.surfaceTint,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String message;
  final Color color;
  final Color background;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) Text(title!, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                    if (title != null) const SizedBox(height: AppSpacing.xs),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
        ],
      ),
    );
  }
}

/// Franja naranja y amarilla, como en el logo del CMO.
class BrandStripe extends StatelessWidget {
  const BrandStripe({super.key, this.width = 72});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: const LinearGradient(colors: [AppColors.orange, AppColors.yellow]),
        ),
      ),
    );
  }
}
