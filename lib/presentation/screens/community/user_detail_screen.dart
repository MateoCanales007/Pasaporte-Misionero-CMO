import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/public_profile.dart';
import '../../../domain/models/stamp_redemption.dart';
import '../../../domain/models/user_role.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../passport/widgets/stamp_list.dart';

/// Perfil público de un misionero. Los administradores ven además las
/// herramientas para asignar el rol de presentador y ayudar con el acceso.
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final isMe = ref.watch(currentUidProvider) == profile.uid;
    final stamps = [for (final id in profile.stampIds) StampRedemption(missionId: id, source: RedemptionSource.qr)];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de misionero')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              children: [
                InitialsAvatar(initials: profile.initials, radius: 50),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                if (profile.cellName != null)
                  _HeaderLine(icon: Icons.groups_rounded, text: 'Célula: ${profile.cellName}'),
                if (profile.nationality != null) _HeaderLine(icon: Icons.flag_rounded, text: profile.nationality!),
                _HeaderLine(icon: Icons.approval_rounded, text: '${profile.stampCount} sellos'),
              ],
            ),
          ),
          if (isAdmin && !isMe) _AdminTools(profile: profile),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ResponsiveCenter(
              child: StampList(
                stamps: AsyncData(stamps),
                emptyMessage: 'Aún no ha obtenido sellos misioneros.',
                showDates: false,
                title: 'Sellos obtenidos',
                emptyTitle: 'Sin sellos todavía',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

class _AdminTools extends ConsumerStatefulWidget {
  const _AdminTools({required this.profile});

  final PublicProfile profile;

  @override
  ConsumerState<_AdminTools> createState() => _AdminToolsState();
}

class _AdminToolsState extends ConsumerState<_AdminTools> {
  bool _busy = false;

  Future<void> _setPresenter(AppUser? user, bool enable) async {
    final name = widget.profile.displayName;
    final confirmed = await showConfirmDialog(
      context,
      title: enable ? '¿Autorizar como presentador?' : '¿Quitar el permiso?',
      message: enable
          ? '$name podrá mostrar el código QR de las misiones activas. No podrá crear ni editar sellos.'
          : '$name ya no podrá mostrar el código QR de las misiones.',
      confirmLabel: enable ? 'Autorizar' : 'Quitar permiso',
      destructive: !enable,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .setUserRole(widget.profile.uid, enable ? UserRole.qrPresenter : UserRole.user);
      if (mounted) {
        showAppSnackBar(
          context,
          enable ? '$name ahora es presentador de QR.' : 'Se quitó el permiso a $name.',
          type: SnackType.success,
        );
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRecoveryCode() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Generar código de recuperación?',
      message:
          'Hazlo solo si confirmaste por WhatsApp que realmente es ${widget.profile.displayName}. '
          'El código vence en 30 minutos y queda registrado.',
      confirmLabel: 'Generar código',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final code = await ref.read(communityRepositoryProvider).createRecoveryCode(widget.profile.uid);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de recuperación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                code.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Envíalo por WhatsApp. En la app, la persona debe tocar "¿Olvidaste tu contraseña?", '
                'escribir su usuario, y luego este código y su nueva contraseña.\n\n'
                'Vence a las ${BusinessTime.formatTime(code.expiresAt)} (hora de El Salvador).',
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code.code));
                showAppSnackBar(context, 'Código copiado.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final privateProfile = ref.watch(privateProfileProvider(widget.profile.uid));
    final user = privateProfile.value;
    final role = user?.storedRole ?? UserRole.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ResponsiveCenter(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Opciones de administrador', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (privateProfile.isLoading)
                  const LinearProgressIndicator()
                else ...[
                  Text('Rol actual: ${role.label}', style: theme.textTheme.bodyLarge),
                  if (user?.hasRequestedDeletion ?? false) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InfoBanner(
                      icon: Icons.person_remove_rounded,
                      color: AppColors.error,
                      background: AppColors.errorSurface,
                      title: 'Solicitó eliminar su cuenta',
                      message:
                          'Fecha: ${BusinessTime.formatLongDate(user!.deletionRequestedAt!)}. '
                          'Sigue el procedimiento de eliminación documentado.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (role == UserRole.admin)
                    const Text('Los administradores no se pueden modificar desde la app.')
                  else
                    Card(
                      color: AppColors.background,
                      child: SwitchListTile(
                        value: role == UserRole.qrPresenter,
                        onChanged: _busy ? null : (value) => _setPresenter(user, value),
                        title: const Text('Presentador de QR'),
                        subtitle: const Text('Puede mostrar el código QR de la misión activa.'),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createRecoveryCode,
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Ayudar a recuperar acceso'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
