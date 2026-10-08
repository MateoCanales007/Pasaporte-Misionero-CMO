import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/support_contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/text_utils.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/notification_prefs.dart';
import '../../providers/notification_status_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import '../auth/auth_screen.dart';
import '../journal/journal_screen.dart';
import 'edit_profile_screen.dart';
import 'widgets/download_app_card.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<AppUser?>(
      value: ref.watch(currentUserProvider),
      onRetry: () => ref.invalidate(currentUserProvider),
      data: (user) {
        if (user == null) return const LoadingView();
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(user: user),
                  const SectionTitle('Mis datos', icon: Icons.badge_rounded),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.edit_rounded, size: 28),
                      title: const Text('Editar nombre, nacionalidad y célula'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: user))),
                    ),
                  ),
                  const SectionTitle('Privacidad en Comunidad', icon: Icons.shield_rounded),
                  _PrivacySettings(user: user),
                  const SectionTitle('Avisos', icon: Icons.notifications_rounded),
                  _NotificationSettings(user: user),
                  const SectionTitle('Mi diario', icon: Icons.menu_book_rounded),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_stories_rounded, size: 28),
                      title: const Text('Mi diario de oración'),
                      subtitle: const Text('Reflexiones privadas, solo para ti.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalScreen())),
                    ),
                  ),
                  const SectionTitle('Ayuda y cuenta', icon: Icons.help_rounded),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_rounded, size: 28, color: AppColors.success),
                      title: const Text('Hablar con soporte por WhatsApp'),
                      subtitle: Text(SupportContact.displayPhone),
                      onTap: () => SupportContact.openWhatsApp(
                        'Hola, soy el usuario "${user.username}" y necesito ayuda con mi Pasaporte Misionero Virtual.',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _LogoutButton(),
                  const SizedBox(height: AppSpacing.md),
                  _DeleteAccountButton(user: user),
                  const SectionTitle('Descargar la app', icon: Icons.install_mobile_rounded),
                  const DownloadAppCard(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Versión ${ref.watch(appVersionProvider)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        children: [
          InitialsAvatar(initials: initialsFor(user.fullName), radius: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: theme.textTheme.headlineSmall),
                Text('Usuario: ${user.username}', style: theme.textTheme.bodyMedium),
                Text('Pasaporte: ${user.passportNumber}', style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                StatusChip.info(role.label, icon: Icons.verified_user_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySettings extends ConsumerWidget {
  const _PrivacySettings({required this.user});

  final AppUser user;

  Future<void> _update(BuildContext context, WidgetRef ref, ProfileUpdate update) async {
    try {
      await ref.read(userRepositoryProvider).updateProfile(user.uid, update);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = user.hasRequestedDeletion;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: user.communityVisible && !disabled,
            onChanged: disabled ? null : (v) => _update(context, ref, ProfileUpdate(communityVisible: v)),
            title: const Text('Aparecer en Comunidad'),
            subtitle: const Text('Otros misioneros verán tu nombre y tus sellos.'),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: user.showCell,
            onChanged: disabled ? null : (v) => _update(context, ref, ProfileUpdate(showCell: v)),
            title: const Text('Mostrar mi célula'),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: user.showNationality,
            onChanged: disabled ? null : (v) => _update(context, ref, ProfileUpdate(showNationality: v)),
            title: const Text('Mostrar mi nacionalidad'),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Tu fecha de nacimiento nunca se muestra a nadie.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings({required this.user});

  final AppUser user;

  Future<void> _setPrefs(BuildContext context, WidgetRef ref, NotificationPrefs prefs) async {
    try {
      await ref.read(userRepositoryProvider).updateProfile(user.uid, ProfileUpdate(notificationPrefs: prefs));
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationStatusProvider).value;
    final prefs = user.notificationPrefs;
    final notifier = ref.read(notificationStatusProvider.notifier);

    return Card(
      child: Column(
        children: [
          if (status != null && status.supported)
            SwitchListTile(
              value: status.enabled,
              onChanged: (enable) async {
                if (enable) {
                  final granted = await notifier.enable();
                  if (!granted && context.mounted) {
                    showAppSnackBar(
                      context,
                      'No se concedió el permiso. Actívalo en los ajustes del teléfono o del navegador.',
                    );
                  }
                } else {
                  await notifier.disable();
                }
              },
              title: const Text('Recibir avisos en este dispositivo'),
            )
          else
            const ListTile(
              leading: Icon(Icons.notifications_off_rounded),
              title: Text('Este dispositivo no admite avisos.'),
            ),
          const Divider(height: 1),
          CheckboxListTile(
            value: prefs.newMission,
            onChanged: (v) => _setPrefs(context, ref, prefs.copyWith(newMission: v)),
            title: const Text('Nuevas misiones'),
          ),
          CheckboxListTile(
            value: prefs.missionReminder,
            onChanged: (v) => _setPrefs(context, ref, prefs.copyWith(missionReminder: v)),
            title: const Text('Misión por comenzar'),
          ),
          CheckboxListTile(
            value: prefs.newSermon,
            onChanged: (v) => _setPrefs(context, ref, prefs.copyWith(newSermon: v)),
            title: const Text('Nuevas prédicas'),
          ),
          CheckboxListTile(
            value: prefs.stampConfirmed,
            onChanged: (v) => _setPrefs(context, ref, prefs.copyWith(stampConfirmed: v)),
            title: const Text('Sello confirmado'),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showConfirmDialog(
          context,
          title: '¿Cerrar sesión?',
          message: 'Tendrás que escribir tu usuario y contraseña para volver a entrar.',
          confirmLabel: 'Cerrar sesión',
        );
        if (!confirmed) return;
        final uid = ref.read(currentUidProvider);
        if (uid != null) await ref.read(notificationRepositoryProvider).disableOnThisDevice(uid);
        await ref.read(authRepositoryProvider).logout();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
      },
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Cerrar sesión'),
    );
  }
}

class _DeleteAccountButton extends ConsumerWidget {
  const _DeleteAccountButton({required this.user});

  final AppUser user;

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Solicitar la eliminación de tu cuenta?',
      message:
          'Dejarás de aparecer en Comunidad de inmediato. Un administrador eliminará tu cuenta y tus datos '
          'personales. Esta acción no se puede deshacer una vez procesada.',
      confirmLabel: 'Sí, solicitar eliminación',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(userRepositoryProvider).requestAccountDeletion();
      if (context.mounted) {
        showAppSnackBar(context, 'Recibimos tu solicitud. Te contactaremos si es necesario.', type: SnackType.success);
      }
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.hasRequestedDeletion) {
      return const InfoBanner(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        background: AppColors.warningSurface,
        title: 'Solicitud de eliminación enviada',
        message: 'Un administrador procesará tu solicitud. Si cambias de opinión, escríbenos por WhatsApp.',
      );
    }
    return TextButton.icon(
      onPressed: () => _request(context, ref),
      style: TextButton.styleFrom(foregroundColor: AppColors.error),
      icon: const Icon(Icons.person_remove_rounded),
      label: const Text('Solicitar eliminación de mi cuenta'),
    );
  }
}
