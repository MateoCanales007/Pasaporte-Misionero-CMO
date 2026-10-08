import 'dart:async';
import 'dart:typed_data';

import 'package:pasaporte_misionero_cmo/core/errors/app_exception.dart';
import 'package:pasaporte_misionero_cmo/core/network/network_status.dart';
import 'package:pasaporte_misionero_cmo/domain/models/app_user.dart';
import 'package:pasaporte_misionero_cmo/domain/models/auth_identity.dart';
import 'package:pasaporte_misionero_cmo/domain/models/cell.dart';
import 'package:pasaporte_misionero_cmo/domain/models/journal_entry.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/pending_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/public_profile.dart';
import 'package:pasaporte_misionero_cmo/domain/models/qr_models.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/stamp_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/testimonial.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/auth_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/community_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/mission_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/notification_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/sermon_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/stamp_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/repositories/user_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._identity});

  AuthIdentity? _identity;
  String? loginResult;
  final loginCalls = <(String, String)>[];
  final registerCalls = <(String, String)>[];
  PasswordRecoveryResult recoveryResult = PasswordRecoveryResult.success;
  int refreshCalls = 0;

  @override
  AuthIdentity? get currentIdentity => _identity;

  @override
  Stream<AuthIdentity?> watchIdentity() => Stream.value(_identity);

  @override
  Future<String?> login(String username, String password) async {
    loginCalls.add((username, password));
    return loginResult;
  }

  @override
  Future<String?> register(String username, String password) async {
    registerCalls.add((username, password));
    return null;
  }

  @override
  Future<void> logout() async => _identity = null;

  @override
  Future<void> refreshClaims() async => refreshCalls++;

  @override
  Future<PasswordRecoveryResult> recoverWithCode({
    required String username,
    required String code,
    required String newPassword,
  }) async => recoveryResult;
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.user, this.redemptions = const [], this.cells = const []});

  AppUser? user;
  List<StampRedemption> redemptions;
  List<Cell> cells;
  final updates = <ProfileUpdate>[];

  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(user);

  @override
  Future<void> createPassport(String uid, String username, NewPassport data) async {}

  @override
  Future<void> updateProfile(String uid, ProfileUpdate update) async => updates.add(update);

  @override
  Stream<List<StampRedemption>> watchRedemptions(String uid) => Stream.value(redemptions);

  @override
  Future<void> requestAccountDeletion({String? reason}) async {}

  @override
  Stream<List<Cell>> watchCells() => Stream.value(cells);
}

class FakeMissionRepository implements MissionRepository {
  FakeMissionRepository({this.missions = const []});

  List<Mission> missions;
  final saved = <MissionDraft>[];
  Object? saveError;

  @override
  Stream<List<Mission>> watchMissions() => Stream.value(missions);

  @override
  Future<String> saveMission(MissionDraft draft) async {
    if (saveError != null) throw saveError!;
    saved.add(draft);
    return draft.id ?? 'new-id';
  }

  @override
  Future<void> setMissionStatus(String missionId, MissionStatus status) async {}

  @override
  Future<UploadedImage> uploadMissionImage(Uint8List bytes, String contentType) async =>
      const UploadedImage(downloadUrl: 'https://example.com/img.jpg', storagePath: 'mission_images/x/img.jpg');
}

class FakeMissionPhotoRepository implements MissionPhotoRepository {
  final photos = <String, List<MissionPhoto>>{};
  final uploads = <String>[];

  @override
  Future<List<MissionPhoto>> servicePhotos(String missionId) async => [...?photos[missionId]];

  @override
  Future<MissionPhoto> uploadServicePhoto(String missionId, Uint8List bytes, String contentType) async {
    uploads.add(missionId);
    final photo = MissionPhoto(
      url: '',
      originalUrl: '',
      storagePath: 'mission_service_photos/$missionId/culto_${uploads.length}.jpg',
    );
    (photos[missionId] ??= []).insert(0, photo);
    return photo;
  }

  @override
  Future<void> deleteServicePhoto(MissionPhoto photo) async {
    for (final list in photos.values) {
      list.removeWhere((p) => p.storagePath == photo.storagePath);
    }
  }
}

class FakePlacesRepository implements PlacesRepository {
  final queries = <String>[];
  List<PlaceSuggestion> results = const [PlaceSuggestion(placeId: 'p1', description: 'Catedral de San Salvador')];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    queries.add(query);
    return results;
  }

  @override
  Future<GeoLocation> locationOf(String placeId) async => const GeoLocation(13.6989, -89.1914);

  @override
  Future<List<String>> photoReferences({String? placeId, GeoLocation? near}) async => const [];

  @override
  Future<Uint8List> photo(String photoReference) async => Uint8List(0);
}

class FakeStampRepository implements StampRepository {
  final redeemResults = <Object>[];
  final redeemedTokens = <String>[];
  QrIssueResult issueResult = const NoActiveMission();
  int issueCalls = 0;

  @override
  Future<QrIssueResult> issueQrToken({String? missionId}) async {
    issueCalls++;
    return issueResult;
  }

  @override
  Future<RedemptionResult> redeem(String token) async {
    redeemedTokens.add(token);
    final next = redeemResults.isEmpty ? const NetworkException() : redeemResults.removeAt(0);
    if (next is RedemptionResult) return next;
    throw next;
  }
}

class InMemoryPendingStore implements PendingRedemptionStore {
  final Map<String, List<PendingRedemption>> data = {};

  @override
  Future<List<PendingRedemption>> load(String uid) async => [...?data[uid]];

  @override
  Future<void> save(String uid, List<PendingRedemption> items) async => data[uid] = [...items];
}

class FakeSermonRepository implements SermonRepository {
  FakeSermonRepository({this.sermons = const [], this.error});

  List<Sermon> sermons;
  Object? error;
  final saved = <SermonDraft>[];
  final metadataRequests = <String>[];
  VideoMetadataResult metadataResult = const VideoMetadataFound(
    VideoMetadata(
      platform: VideoPlatform.youtube,
      domain: 'youtube.com',
      canonicalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      metadataAvailable: true,
      externalVideoId: 'dQw4w9WgXcQ',
      title: 'Prédica dominical',
      thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    ),
  );
  bool? lastIncludeHidden;

  @override
  Stream<List<Sermon>> watchSermons({required bool includeHidden}) {
    lastIncludeHidden = includeHidden;
    if (error != null) return Stream.error(error!);
    return Stream.value(includeHidden ? sermons : sermons.where((s) => s.active).toList());
  }

  @override
  String newSermonId() => 'sermon-new';

  @override
  Future<void> save(SermonDraft draft, {required String editorUid}) async => saved.add(draft);

  @override
  Future<void> setActive(String sermonId, bool active, {required String editorUid}) async {}

  @override
  Future<void> softDelete(String sermonId, {required String editorUid}) async {}

  @override
  Future<void> restore(String sermonId, {required String editorUid}) async {}

  @override
  Future<VideoMetadataResult> fetchMetadata(String url) async {
    metadataRequests.add(url);
    return metadataResult;
  }

  @override
  Future<UploadedImage> uploadCover(String sermonId, Uint8List bytes, String contentType) async =>
      const UploadedImage(downloadUrl: 'https://example.com/c.jpg', storagePath: 'sermon_covers/s/c.jpg');
}

class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({this.profiles = const [], this.privateUser});

  List<PublicProfile> profiles;
  AppUser? privateUser;
  final roleChanges = <(String, UserRole)>[];

  @override
  Stream<List<PublicProfile>> watchProfiles({required bool includeHidden}) =>
      Stream.value(includeHidden ? profiles : profiles.where((p) => p.communityVisible).toList());

  @override
  Stream<AppUser?> watchPrivateProfile(String uid) => Stream.value(privateUser);

  @override
  Future<void> setUserRole(String uid, UserRole role) async => roleChanges.add((uid, role));

  @override
  Future<RecoveryCode> createRecoveryCode(String uid) async =>
      RecoveryCode(code: 'ABCD2345', expiresAt: DateTime.utc(2026, 10, 6, 20));
}

class FakeTestimonialRepository implements TestimonialRepository {
  List<Testimonial> approved = const [];
  List<Testimonial> pending = const [];

  @override
  Stream<List<Testimonial>> watchApproved() => Stream.value(approved);

  @override
  Stream<List<Testimonial>> watchMine(String uid) => Stream.value(const []);

  @override
  Stream<List<Testimonial>> watchPending() => Stream.value(pending);

  @override
  Future<void> submit({
    required String uid,
    required String displayName,
    required String text,
    String? missionId,
  }) async {}

  @override
  Future<void> moderate(String id, TestimonialStatus status, {required String moderatorUid}) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeJournalRepository implements JournalRepository {
  List<JournalEntry> entries = const [];

  @override
  Stream<List<JournalEntry>> watchEntries(String uid) => Stream.value(entries);

  @override
  Future<void> save(
    String uid, {
    String? entryId,
    required String text,
    String? missionId,
    String? missionName,
  }) async {}

  @override
  Future<void> delete(String uid, String entryId) async {}
}

class FakeNotificationRepository implements NotificationRepository {
  @override
  bool get isSupported => false;

  @override
  Future<bool> enableOnThisDevice(String uid) async => false;

  @override
  Future<void> refreshRegistration(String uid) async {}

  @override
  Future<void> disableOnThisDevice(String uid) async {}

  @override
  Future<bool> isEnabledOnThisDevice() async => false;

  @override
  Stream<InAppNotification> get foregroundMessages => const Stream.empty();
}

class FakeNetworkStatus implements NetworkStatus {
  bool offline = false;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();

  @override
  Future<bool> isOffline() async => offline;
}
