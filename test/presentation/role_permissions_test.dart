import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/public_profile.dart';
import 'package:pasaporte_misionero_cmo/domain/models/service_photo.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/community/user_detail_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/home/home_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/mission_detail_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/missions_tab.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/qr/qr_presenter_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(initTestLocale);

  group('Pantalla principal según el rol', () {
    testWidgets('un usuario normal ve "Escanear sello" y no "Mostrar QR"', (tester) async {
      await pumpTestApp(tester, const HomeScreen(), TestDeps());
      expect(find.text('ESCANEAR SELLO'), findsOneWidget);
      expect(find.text('MOSTRAR QR'), findsNothing);
      for (final label in ['Pasaporte', 'Misiones', 'Prédicas', 'Comunidad', 'Perfil']) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('un presentador ve "Mostrar QR"', (tester) async {
      await pumpTestApp(tester, const HomeScreen(), TestDeps(role: UserRole.qrPresenter));
      expect(find.text('MOSTRAR QR'), findsOneWidget);
      expect(find.text('ESCANEAR SELLO'), findsNothing);
    });

    testWidgets('todos los roles pueden abrir la pestaña Prédicas', (tester) async {
      for (final role in UserRole.values) {
        await pumpTestApp(tester, const HomeScreen(), TestDeps(role: role));
        await tester.tap(find.text('Prédicas').last);
        await tester.pump();
        expect(find.text('Aún no hay prédicas'), findsOneWidget, reason: role.name);
      }
    });
  });

  group('Misiones según el rol', () {
    testWidgets('solo el administrador ve "Crear misión"', (tester) async {
      final deps = TestDeps(role: UserRole.admin);
      await pumpTestApp(tester, const Scaffold(body: MissionsTab()), deps);
      expect(find.text('Crear misión'), findsOneWidget);

      await pumpTestApp(tester, const Scaffold(body: MissionsTab()), TestDeps(role: UserRole.qrPresenter));
      expect(find.text('Crear misión'), findsNothing);

      await pumpTestApp(tester, const Scaffold(body: MissionsTab()), TestDeps());
      expect(find.text('Crear misión'), findsNothing);
    });

    testWidgets('los borradores solo los ve el administrador', (tester) async {
      Mission draft() => Mission(id: 'd1', name: 'Misión secreta', isoCode: 'GT', status: MissionStatus.draft);
      final userDeps = TestDeps()..missions.missions = [draft()];
      await pumpTestApp(tester, const Scaffold(body: MissionsTab()), userDeps);
      expect(find.text('Misión secreta'), findsNothing);

      final adminDeps = TestDeps(role: UserRole.admin)..missions.missions = [draft()];
      await pumpTestApp(tester, const Scaffold(body: MissionsTab()), adminDeps);
      expect(find.text('Misión secreta'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
    });
  });

  group('Perfil de otro misionero', () {
    const profile = PublicProfile(uid: 'u2', displayName: 'Juan Pérez', initials: 'JP', stampCount: 0);

    testWidgets('un usuario normal no ve las opciones de administrador', (tester) async {
      await pumpTestApp(tester, const UserDetailScreen(profile: profile), TestDeps());
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Opciones de administrador'), findsNothing);
      expect(find.text('Presentador de QR'), findsNothing);
    });

    testWidgets('el administrador puede autorizar un presentador con confirmación', (tester) async {
      final deps = TestDeps(role: UserRole.admin);
      deps.community.privateUser = testUser(uid: 'u2', name: 'Juan Pérez');
      await pumpTestApp(tester, const UserDetailScreen(profile: profile), deps);
      expect(find.text('Opciones de administrador'), findsOneWidget);

      await tester.tap(find.text('Presentador de QR'));
      await tester.pumpAndSettle();
      expect(find.text('¿Autorizar como presentador?'), findsOneWidget);
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();
      expect(deps.community.roleChanges.single, ('u2', UserRole.qrPresenter));
    });
  });

  testWidgets('la pantalla del QR rechaza a un usuario sin rol de presentador', (tester) async {
    final deps = TestDeps();
    await pumpTestApp(tester, const QrPresenterScreen(), deps);
    expect(find.textContaining('Solo los presentadores autorizados'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('Fotos del culto', () {
    TestDeps depsWith(UserRole role) =>
        TestDeps(role: role)
          ..missions.missions = [Mission(id: 'm1', name: 'Guatemala', isoCode: 'GT', status: MissionStatus.active)];

    testWidgets('todos ven la sección; solo el admin puede agregar fotos', (tester) async {
      for (final role in [UserRole.user, UserRole.qrPresenter]) {
        await pumpTestApp(tester, const MissionDetailScreen(missionId: 'm1'), depsWith(role));
        await tester.scrollUntilVisible(find.text('Fotos del culto'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('Aún no hay fotos del culto.'), findsOneWidget, reason: role.name);
        expect(find.text('Agregar fotos del culto'), findsNothing, reason: role.name);
      }
      await pumpTestApp(tester, const MissionDetailScreen(missionId: 'm1'), depsWith(UserRole.admin));
      await tester.scrollUntilVisible(
        find.text('Agregar fotos del culto'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Agregar fotos del culto'), findsOneWidget);
    });

    testWidgets('las fotos subidas se muestran', (tester) async {
      final deps = depsWith(UserRole.user);
      deps.servicePhotos.albums[const PhotoAlbum.mission('m1')] = [
        const ServicePhoto(url: '', originalUrl: '', storagePath: 'mission_service_photos/m1/culto_1.jpg'),
      ];
      await pumpTestApp(tester, const MissionDetailScreen(missionId: 'm1'), deps);
      await tester.scrollUntilVisible(find.text('Fotos del culto'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.bySemanticsLabel(RegExp('Foto del culto 1')), findsOneWidget);
      expect(find.text('Aún no hay fotos del culto.'), findsNothing);
    });
  });
}
