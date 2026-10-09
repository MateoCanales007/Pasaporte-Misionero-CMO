import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/mission_form_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(initTestLocale);

  Future<void> fillBasics(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la misión'), 'Guatemala');
    await tester.enterText(find.widgetWithText(TextFormField, 'Código del país (ISO)'), 'gt');
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar misión'));
    await tester.pump();
    await tester.tap(find.text('Guardar misión'));
    await tester.pump();
  }

  testWidgets('el presentador de QR no puede crear ni editar sellos', (tester) async {
    await pumpTestApp(tester, const MissionFormScreen(), TestDeps(role: UserRole.qrPresenter));
    expect(find.textContaining('Solo los administradores'), findsOneWidget);
    expect(find.text('Guardar misión'), findsNothing);
  });

  testWidgets('valida campos obligatorios y ubicación antes de guardar', (tester) async {
    final deps = TestDeps(role: UserRole.admin);
    await pumpTestApp(tester, const MissionFormScreen(), deps);
    await tapSave(tester);
    expect(find.text('Escribe el nombre (mínimo 2 letras)'), findsOneWidget);
    expect(find.text('Escribe de 2 a 6 letras'), findsOneWidget);
    expect(find.text('Elige una ubicación.'), findsOneWidget);
    expect(deps.missions.saved, isEmpty);
  });

  testWidgets('modo edición carga los valores y detecta horarios superpuestos', (tester) async {
    final start = DateTime.utc(2026, 10, 11, 15);
    final mission = Mission(
      id: 'm1',
      name: 'Honduras',
      isoCode: 'HN',
      status: MissionStatus.active,
      location: const GeoLocation(14.1, -87.2),
      schedules: [
        MissionSchedule(start: start, end: start.add(const Duration(hours: 3))),
        MissionSchedule(start: start.add(const Duration(hours: 1)), end: start.add(const Duration(hours: 4))),
      ],
    );
    final deps = TestDeps(role: UserRole.admin);
    await pumpTestApp(tester, MissionFormScreen(initial: mission), deps);

    expect(find.text('Editar misión'), findsOneWidget);
    expect(find.text('Honduras'), findsWidgets);
    expect(find.text('HN'), findsWidgets);
    expect(find.text('Horario 2'), findsOneWidget);
    expect(find.text('Este horario se cruza con el horario 1.'), findsOneWidget);

    await tapSave(tester);
    expect(deps.missions.saved, isEmpty);

    await tester.ensureVisible(find.text('Quitar').last);
    await tester.pump();
    await tester.tap(find.text('Quitar').last);
    await tester.pump();
    expect(find.text('Este horario se cruza con el horario 1.'), findsNothing);

    await tapSave(tester);
    final saved = deps.missions.saved.single;
    expect(saved.id, 'm1');
    expect(saved.schedules, hasLength(1));
    expect(saved.location, const GeoLocation(14.1, -87.2));
  });

  testWidgets('crea una misión usando el buscador de lugares con espera', (tester) async {
    final deps = TestDeps(role: UserRole.admin);
    await pumpTestApp(tester, const MissionFormScreen(), deps);
    await fillBasics(tester);

    final search = find.widgetWithText(TextField, 'Buscar un lugar');
    await tester.ensureVisible(search);
    await tester.pump();
    await tester.enterText(search, 'Cat');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, 'Catedral');
    expect(deps.places.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(deps.places.queries, ['Catedral']);

    await tester.tap(find.text('Catedral de San Salvador'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Ubicación elegida'), findsOneWidget);

    expect(find.text('Así verán los misioneros esta misión:'), findsOneWidget);
    await tapSave(tester);
    await tester.pump();
    final saved = deps.missions.saved.single;
    expect(saved.isNew, isTrue);
    expect(saved.name, 'Guatemala');
    expect(saved.isoCode, 'GT');
    expect(saved.placeId, 'p1');
    expect(saved.status, MissionStatus.active);
    expect(saved.schedules.single.isValid, isTrue);
  });

  testWidgets('duplicar crea un borrador nuevo', (tester) async {
    final mission = Mission(
      id: 'm1',
      name: 'Honduras',
      isoCode: 'HN',
      status: MissionStatus.active,
      location: const GeoLocation(14.1, -87.2),
      schedules: [MissionSchedule(start: DateTime.utc(2026, 10, 11, 15), end: DateTime.utc(2026, 10, 11, 18))],
    );
    final deps = TestDeps(role: UserRole.admin);
    await pumpTestApp(tester, MissionFormScreen(initial: mission, duplicate: true), deps);
    expect(find.text('Honduras (copia)'), findsWidgets);
    await tapSave(tester);
    final saved = deps.missions.saved.single;
    expect(saved.id, isNull);
    expect(saved.status, MissionStatus.draft);
  });

  testWidgets('pide confirmación antes de descartar cambios', (tester) async {
    final deps = TestDeps(role: UserRole.admin);
    await pumpTestApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionFormScreen())),
            child: const Text('abrir'),
          ),
        ),
      ),
      deps,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la misión'), 'Algo');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva misión'), findsOneWidget);
  });
}
