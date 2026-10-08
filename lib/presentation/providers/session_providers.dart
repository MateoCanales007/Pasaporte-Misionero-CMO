import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/auth_identity.dart';
import '../../domain/models/user_role.dart';
import 'repository_providers.dart';

/// Identidad autenticada (uid + rol del token). Se actualiza al refrescar el token.
final authIdentityProvider = StreamProvider<AuthIdentity?>((ref) => ref.watch(authRepositoryProvider).watchIdentity());

final currentUidProvider = Provider<String?>((ref) => ref.watch(authIdentityProvider.select((a) => a.value?.uid)));

/// Rol efectivo según los Custom Claims. Solo controla qué se muestra; la
/// seguridad real la aplican las reglas y Cloud Functions.
final currentRoleProvider = Provider<UserRole>(
  (ref) => ref.watch(authIdentityProvider.select((a) => a.value?.role)) ?? UserRole.user,
);

/// Perfil privado del usuario actual.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});
