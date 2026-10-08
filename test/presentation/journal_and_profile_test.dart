import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/journal_entry.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/journal/journal_entry_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/journal/journal_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/profile/profile_tab.dart';

import '../helpers/test_app.dart';

Widget _largeText(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
    child: child,
  ),
);

void main() {
  setUpAll(initTestLocale);

  group('Mi diario de oración', () {
    testWidgets('sin reflexiones invita a escribir la primera', (tester) async {
      await pumpTestApp(tester, const JournalScreen(), TestDeps());
      expect(find.text('Tu diario está vacío'), findsOneWidget);
      expect(find.text('Escribir mi primera reflexión'), findsOneWidget);
      expect(find.textContaining('Orad sin cesar'), findsOneWidget);
    });

    testWidgets('agrupa por mes y muestra el estado de guardado (letra grande, teléfono)', (tester) async {
      final deps = TestDeps();
      deps.journal.entries = [
        JournalEntry(id: 'a', text: 'Gracias Señor por la misión', createdAt: DateTime.utc(2026, 10, 5, 18)),
        JournalEntry(
          id: 'b',
          text: 'Oré por Guatemala',
          missionName: 'Guatemala',
          createdAt: DateTime.utc(2026, 9, 20, 18),
          hasPendingWrites: true,
        ),
      ];
      await pumpTestApp(tester, _largeText(const JournalScreen()), deps, size: const Size(360, 740));
      expect(find.text('2 reflexiones'), findsOneWidget);
      expect(find.text('Octubre de 2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Pendiente de guardar'), 300);
      expect(find.text('Septiembre de 2026'), findsOneWidget);
    });

    testWidgets('la hoja para escribir no se desborda con letra grande', (tester) async {
      await pumpTestApp(
        tester,
        _largeText(const JournalEntryScreen(missionId: 'm1', missionName: 'Guatemala')),
        TestDeps(),
        size: const Size(360, 740),
      );
      expect(find.textContaining('Misión: Guatemala'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
    });
  });

  testWidgets('Perfil ofrece descargar la app y copiar el enlace', (tester) async {
    await pumpTestApp(tester, const Scaffold(body: ProfileTab()), TestDeps());
    await tester.scrollUntilVisible(find.text('Descargar la app').last, 300);
    expect(find.text('Copiar enlace para compartir'), findsOneWidget);
  });
}
