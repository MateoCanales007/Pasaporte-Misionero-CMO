import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_status.dart';
import '../../data/datasources/connectivity_network_status.dart';
import '../../data/datasources/shared_prefs_pending_redemption_store.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firebase_community_repository.dart';
import '../../data/repositories/firebase_mission_photo_repository.dart';
import '../../data/repositories/firebase_mission_repository.dart';
import '../../data/repositories/firebase_notification_repository.dart';
import '../../data/repositories/firebase_sermon_repository.dart';
import '../../data/repositories/firebase_stamp_repository.dart';
import '../../data/repositories/firebase_user_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/community_repository.dart';
import '../../domain/repositories/mission_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/sermon_repository.dart';
import '../../domain/repositories/stamp_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/use_cases/redeem_stamp_use_case.dart';

/// Composición de dependencias. Las pruebas reemplazan estos providers con
/// implementaciones falsas mediante `ProviderScope(overrides: [...])`.

/// Versión de la app (se completa en `main` con package_info_plus).
final appVersionProvider = Provider<String>((ref) => 'dev');

/// Reloj inyectable para lógica dependiente del tiempo.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final _functionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: 'us-central1'));

final networkStatusProvider = Provider<NetworkStatus>((ref) => ConnectivityNetworkStatus());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance, ref.watch(_functionsProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirebaseUserRepository(FirebaseFirestore.instance, ref.watch(_functionsProvider)),
);

final missionRepositoryProvider = Provider<MissionRepository>(
  (ref) =>
      FirebaseMissionRepository(FirebaseFirestore.instance, ref.watch(_functionsProvider), FirebaseStorage.instance),
);

final missionPhotoRepositoryProvider = Provider<MissionPhotoRepository>(
  (ref) => FirebaseMissionPhotoRepository(FirebaseStorage.instance),
);

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => FirebasePlacesRepository(ref.watch(_functionsProvider)),
);

final stampRepositoryProvider = Provider<StampRepository>((ref) {
  final network = ref.watch(networkStatusProvider);
  return FirebaseStampRepository(
    ref.watch(_functionsProvider),
    isOffline: network.isOffline,
    appVersion: ref.watch(appVersionProvider),
    platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
  );
});

final pendingRedemptionStoreProvider = Provider<PendingRedemptionStore>((ref) => SharedPrefsPendingRedemptionStore());

final redeemStampUseCaseProvider = Provider<RedeemStampUseCase>(
  (ref) => RedeemStampUseCase(
    repository: ref.watch(stampRepositoryProvider),
    store: ref.watch(pendingRedemptionStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

final sermonRepositoryProvider = Provider<SermonRepository>(
  (ref) =>
      FirebaseSermonRepository(FirebaseFirestore.instance, ref.watch(_functionsProvider), FirebaseStorage.instance),
);

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => FirebaseCommunityRepository(FirebaseFirestore.instance, ref.watch(_functionsProvider)),
);

final testimonialRepositoryProvider = Provider<TestimonialRepository>(
  (ref) => FirebaseTestimonialRepository(FirebaseFirestore.instance),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => FirebaseJournalRepository(FirebaseFirestore.instance),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirebaseNotificationRepository(FirebaseMessaging.instance, FirebaseFirestore.instance),
);
