import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pasaporte_misionero_cmo/core/theme/app_theme.dart';
import 'package:pasaporte_misionero_cmo/domain/models/app_user.dart';
import 'package:pasaporte_misionero_cmo/domain/models/auth_identity.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/providers/repository_providers.dart';
import 'package:pasaporte_misionero_cmo/presentation/widgets/map_view.dart';

import 'fakes.dart';

/// Hora fija usada en las pruebas (domingo 4 oct 2026, 10:00 en El Salvador).
final testNow = DateTime.utc(2026, 10, 4, 16);

Future<void> initTestLocale() => initializeDateFormatting('es');

AppUser testUser({String uid = 'u1', String name = 'María López', UserRole storedRole = UserRole.user}) => AppUser(
  uid: uid,
  username: 'maria',
  passportNumber: 'PM-2026-U1AB',
  fullName: name,
  nationality: 'Salvadoreña',
  cellId: 'c1',
  storedRole: storedRole,
);

/// Dependencias falsas para montar pantallas sin Firebase.
class TestDeps {
  TestDeps({UserRole role = UserRole.user, AppUser? user, bool signedIn = true})
    : auth = FakeAuthRepository(
        identity: signedIn ? AuthIdentity(uid: 'u1', username: 'maria', role: role) : null,
      ),
      users = FakeUserRepository(user: user ?? testUser());

  final FakeAuthRepository auth;
  final FakeUserRepository users;
  final missions = FakeMissionRepository();
  final places = FakePlacesRepository();
  final missionPhotos = FakeMissionPhotoRepository();
  final stamps = FakeStampRepository();
  final pending = InMemoryPendingStore();
  final sermons = FakeSermonRepository();
  final community = FakeCommunityRepository();
  final testimonials = FakeTestimonialRepository();
  final journal = FakeJournalRepository();
  final notifications = FakeNotificationRepository();
  final network = FakeNetworkStatus();

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    missionRepositoryProvider.overrideWithValue(missions),
    placesRepositoryProvider.overrideWithValue(places),
    missionPhotoRepositoryProvider.overrideWithValue(missionPhotos),
    stampRepositoryProvider.overrideWithValue(stamps),
    pendingRedemptionStoreProvider.overrideWithValue(pending),
    sermonRepositoryProvider.overrideWithValue(sermons),
    communityRepositoryProvider.overrideWithValue(community),
    testimonialRepositoryProvider.overrideWithValue(testimonials),
    journalRepositoryProvider.overrideWithValue(journal),
    notificationRepositoryProvider.overrideWithValue(notifications),
    networkStatusProvider.overrideWithValue(network),
    clockProvider.overrideWithValue(() => testNow),
    mapViewBuilderProvider.overrideWithValue(
      ({marker, required center, zoom = 12, onTap}) => const ColoredBox(color: Colors.grey, child: Text('MAPA')),
    ),
  ];
}

/// Monta [child] con el tema, idioma español y las dependencias falsas.
Future<void> pumpTestApp(WidgetTester tester, Widget child, TestDeps deps, {Size size = const Size(800, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: deps.overrides,
      retry: (_, _) => null,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  // Los providers encadenan varios streams: se dejan resolver unos frames.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}
