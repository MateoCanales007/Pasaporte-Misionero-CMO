import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';

import '../../domain/models/achievement.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/mission.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/models/sermon.dart';
import '../../domain/models/stamp_redemption.dart';
import '../../domain/models/testimonial.dart';
import '../../domain/use_cases/achievements_calculator.dart';
import '../../domain/use_cases/passport_stamps.dart';
import 'repository_providers.dart';
import 'session_providers.dart';

// ------------------------------------------------------------------ Misiones

final missionsProvider = StreamProvider<List<Mission>>((ref) => ref.watch(missionRepositoryProvider).watchMissions());

final missionCatalogProvider = Provider<Map<String, Mission>>((ref) {
  final missions = ref.watch(missionsProvider).value ?? const [];
  return {for (final m in missions) m.id: m};
});

/// Misiones que ve el usuario: los borradores solo los ven administradores.
/// Orden: abiertas, próximas (por fecha) y luego finalizadas/inactivas.
final visibleMissionsProvider = Provider<AsyncValue<List<Mission>>>((ref) {
  final isAdmin = ref.watch(currentRoleProvider).isAdmin;
  final now = ref.watch(clockProvider)();
  return ref.watch(missionsProvider).whenData((missions) {
    final visible = missions.where((m) => isAdmin || !m.isDraft).toList();
    int rank(Mission m) => switch (m.phaseAt(now)) {
      MissionPhase.open => 0,
      MissionPhase.upcoming => 1,
      MissionPhase.draft => 2,
      MissionPhase.inactive => 3,
      MissionPhase.finished => 4,
    };
    visible.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final da = a.nextWindow(now)?.start ?? a.sortedSchedules.lastOrNull?.start;
      final db = b.nextWindow(now)?.start ?? b.sortedSchedules.lastOrNull?.start;
      if (da == null || db == null) return a.name.compareTo(b.name);
      return rank(a) == 4 ? db.compareTo(da) : da.compareTo(db);
    });
    return visible;
  });
});

/// Fotos del culto de una misión (se recargan tras subir o borrar).
final servicePhotosProvider = FutureProvider.autoDispose.family<List<MissionPhoto>, String>(
  (ref, missionId) => ref.watch(missionPhotoRepositoryProvider).servicePhotos(missionId),
);

// ------------------------------------------------------------------ Pasaporte

final serverRedemptionsProvider = StreamProvider<List<StampRedemption>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(userRepositoryProvider).watchRedemptions(uid);
});

/// Sellos confirmados del usuario (servidor + arreglo heredado).
///
/// Si las reglas aún no permiten leer `redemptions` (antes del corte a la
/// versión nueva), se muestran los sellos del arreglo heredado.
final passportStampsProvider = Provider<AsyncValue<List<StampRedemption>>>((ref) {
  final legacy = ref.watch(currentUserProvider).value?.legacyStamps ?? const <LegacyStamp>[];
  final server = ref.watch(serverRedemptionsProvider);
  if (server.hasError && server.error is PermissionDeniedException) {
    return AsyncData(mergePassportStamps(const [], legacy));
  }
  return server.whenData((list) => mergePassportStamps(list, legacy));
});

final ownedMissionIdsProvider = Provider<Set<String>>(
  (ref) => {...?ref.watch(passportStampsProvider).value?.map((s) => s.missionId)},
);

final achievementsProvider = Provider<List<Achievement>>((ref) {
  final stamps = ref.watch(passportStampsProvider).value ?? const [];
  return AchievementsCalculator.compute(stamps, ref.watch(missionCatalogProvider));
});

// ------------------------------------------------------------------ Prédicas

final sermonsProvider = StreamProvider<List<Sermon>>((ref) {
  final isAdmin = ref.watch(currentRoleProvider).isAdmin;
  return ref.watch(sermonRepositoryProvider).watchSermons(includeHidden: isAdmin);
});

// ------------------------------------------------------------------ Comunidad

final cellsProvider = StreamProvider<List<Cell>>((ref) => ref.watch(userRepositoryProvider).watchCells());

final communityProfilesProvider = StreamProvider<List<PublicProfile>>((ref) {
  final isAdmin = ref.watch(currentRoleProvider).isAdmin;
  return ref.watch(communityRepositoryProvider).watchProfiles(includeHidden: isAdmin);
});

final privateProfileProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(communityRepositoryProvider).watchPrivateProfile(uid),
);

final approvedTestimonialsProvider = StreamProvider<List<Testimonial>>(
  (ref) => ref.watch(testimonialRepositoryProvider).watchApproved(),
);

final myTestimonialsProvider = StreamProvider<List<Testimonial>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(testimonialRepositoryProvider).watchMine(uid);
});

final pendingTestimonialsProvider = StreamProvider<List<Testimonial>>((ref) {
  if (!ref.watch(currentRoleProvider).isAdmin) return Stream.value(const []);
  return ref.watch(testimonialRepositoryProvider).watchPending();
});

// ------------------------------------------------------------------ Diario

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(journalRepositoryProvider).watchEntries(uid);
});
