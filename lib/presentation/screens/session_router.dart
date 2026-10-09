import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/repository_providers.dart';
import '../providers/session_providers.dart';
import '../widgets/state_views.dart';
import 'auth/auth_screen.dart';
import 'auth/complete_profile_screen.dart';
import 'home/home_screen.dart';

/// Decide entre completar perfil o entrar a la app, y mantiene los roles
/// sincronizados cuando el servidor los cambia.
class SessionRouter extends ConsumerStatefulWidget {
  const SessionRouter({super.key});

  @override
  ConsumerState<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends ConsumerState<SessionRouter> {
  bool _checkedStoredRole = false;

  @override
  Widget build(BuildContext context) {
    // Cuando un admin cambia el rol, el servidor aumenta roleVersion: se
    // refresca el token para leer los nuevos Custom Claims.
    ref.listen(currentUserProvider.select((u) => u.value?.roleVersion), (previous, next) {
      if (previous != null && next != null && previous != next) {
        ref.read(authRepositoryProvider).refreshClaims();
      }
    });

    final identity = ref.watch(authIdentityProvider);
    if (identity.hasValue && identity.value == null) {
      return const AuthScreen();
    }

    final user = ref.watch(currentUserProvider);
    return user.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(backgroundColor: AppColors.navy),
      error: (error, _) => Scaffold(
        body: ErrorView(error: error, onRetry: () => ref.invalidate(currentUserProvider)),
      ),
      data: (profile) {
        if (profile == null) return const CompleteProfileScreen();
        final tokenRole = identity.value?.role;
        if (!_checkedStoredRole && tokenRole != null && profile.storedRole != tokenRole) {
          _checkedStoredRole = true;
          final auth = ref.read(authRepositoryProvider);
          WidgetsBinding.instance.addPostFrameCallback((_) => auth.refreshClaims());
        }
        return const HomeScreen();
      },
    );
  }
}
