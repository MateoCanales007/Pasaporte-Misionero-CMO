import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/public_profile.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/stamp_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/home/home_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/mission_detail_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/mission_form_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/passport/widgets/passport_cover.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/passport/widgets/stamp_list.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/sermons/sermon_form_screen.dart';

import '../helpers/test_app.dart';

/// Teléfono pequeño con letra grande: ninguna pantalla debe desbordarse.
const _phone = Size(360, 740);

Widget _largeText(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
    child: child,
  ),
);

TestDeps _richDeps(UserRole role) {
  final start = testNow.subtract(const Duration(hours: 1));
  final deps = TestDeps(role: role);
  deps.missions.missions = [
    Mission(
      id: 'm1',
      name: 'República Democrática del Congo y naciones vecinas',
      isoCode: 'COD',
      status: MissionStatus.active,
      location: const GeoLocation(-4.3, 15.3),
      schedules: [MissionSchedule(start: start, end: start.add(const Duration(hours: 3)))],
    ),
    Mission(id: 'm2', name: 'Guatemala', isoCode: 'GT', status: MissionStatus.inactive),
  ];
  deps.users.redemptions = [StampRedemption(missionId: 'm1', redeemedAt: testNow, source: RedemptionSource.qr)];
  deps.sermons.sermons = [
    Sermon(
      id: 's1',
      sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      title: 'Una prédica con un título bastante largo para probar el ajuste de línea',
      platform: VideoPlatform.youtube,
      domain: 'youtube.com',
      publishedAt: DateTime.utc(2026, 9, 27, 18),
    ),
  ];
  deps.community.profiles = const [
    PublicProfile(
      uid: 'u2',
      displayName: 'María de los Ángeles Hernández',
      initials: 'MH',
      cellName: 'Célula Jóvenes del Norte',
      nationality: 'Salvadoreña',
      stampCount: 12,
    ),
  ];
  return deps;
}

void main() {
  setUpAll(initTestLocale);

  for (final role in UserRole.values) {
    testWidgets('pestañas principales sin desbordes (${role.name})', (tester) async {
      await pumpTestApp(tester, _largeText(const HomeScreen()), _richDeps(role), size: _phone);
      for (final tab in ['Misiones', 'Prédicas', 'Comunidad', 'Perfil', 'Pasaporte']) {
        await tester.tap(find.text(tab).last);
        await tester.pump();
        await tester.pump();
      }
      await tester.tap(find.byType(PassportCover));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar pasaporte'), findsOneWidget);
      expect(find.text('Página 1'), findsOneWidget);
      // La primera página es "Mis sellos"; luego se pasa a "Mi progreso".
      final pageScroll = find
          .descendant(
            of: find.byType(PageView),
            matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
          )
          .first;
      await tester.scrollUntilVisible(find.byType(StampTile), 300, scrollable: pageScroll);
      expect(find.byType(StampTile), findsWidgets);
      await tester.tap(find.widgetWithText(SegmentedButton<int>, 'Mi progreso'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2'), findsOneWidget);
    });
  }

  testWidgets('detalle de misión sin desbordes', (tester) async {
    await pumpTestApp(
      tester,
      _largeText(const MissionDetailScreen(missionId: 'm1')),
      _richDeps(UserRole.admin),
      size: _phone,
    );
    expect(find.text('Opciones de administrador'), findsOneWidget);
    expect(find.text('Ya tienes este sello'), findsOneWidget);
  });

  testWidgets('formularios de administrador sin desbordes', (tester) async {
    await pumpTestApp(tester, _largeText(const MissionFormScreen()), _richDeps(UserRole.admin), size: _phone);
    expect(find.text('Guardar misión'), findsOneWidget);
    await pumpTestApp(tester, _largeText(const SermonFormScreen()), _richDeps(UserRole.admin), size: _phone);
    expect(find.text('Guardar prédica'), findsOneWidget);
  });
}
