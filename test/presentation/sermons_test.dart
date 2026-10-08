import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/core/errors/app_exception.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/sermons/sermon_form_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/sermons/sermons_tab.dart';

import '../helpers/test_app.dart';

Sermon sermon(String id, String title, {bool active = true}) => Sermon(
  id: id,
  sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  title: title,
  platform: VideoPlatform.youtube,
  domain: 'youtube.com',
  publishedAt: DateTime.utc(2026, 9, 27, 18),
  active: active,
);

void main() {
  setUpAll(initTestLocale);

  group('Pestaña Prédicas', () {
    testWidgets('el usuario ve las prédicas activas sin acciones de administrador', (tester) async {
      final deps = TestDeps()
        ..sermons.sermons = [sermon('1', 'La fe que mueve montañas'), sermon('2', 'Oculta', active: false)];
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), deps);

      expect(find.text('La fe que mueve montañas'), findsOneWidget);
      expect(find.text('Oculta'), findsNothing);
      expect(find.text('Ver prédica'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('La fe que mueve montañas')), findsWidgets);
      expect(find.textContaining('YouTube'), findsOneWidget);
      expect(find.textContaining('27 de septiembre de 2026'), findsOneWidget);
      expect(find.text('Agregar prédica'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(deps.sermons.lastIncludeHidden, isFalse);
    });

    testWidgets('el administrador ve acciones y prédicas ocultas', (tester) async {
      final deps = TestDeps(role: UserRole.admin)
        ..sermons.sermons = [sermon('1', 'Visible'), sermon('2', 'Oculta', active: false)];
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), deps);

      expect(find.text('Agregar prédica'), findsOneWidget);
      expect(find.text('Oculta'), findsOneWidget);
      expect(find.text('Oculta para los misioneros'), findsOneWidget);
      expect(find.text('Editar'), findsNWidgets(2));
      expect(deps.sermons.lastIncludeHidden, isTrue);
    });

    testWidgets('el presentador de QR no puede administrar prédicas', (tester) async {
      final deps = TestDeps(role: UserRole.qrPresenter)..sermons.sermons = [sermon('1', 'Visible')];
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), deps);
      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Agregar prédica'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
    });

    testWidgets('estado vacío y estado de error con reintento', (tester) async {
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), TestDeps());
      expect(find.text('Aún no hay prédicas'), findsOneWidget);

      final failing = TestDeps()..sermons.error = const NetworkException();
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), failing);
      expect(find.textContaining('No hay conexión'), findsOneWidget);
      expect(find.text('Intentar de nuevo'), findsOneWidget);
    });
  });

  group('Formulario de prédicas', () {
    testWidgets('solo administradores pueden abrirlo', (tester) async {
      await pumpTestApp(tester, const SermonFormScreen(), TestDeps());
      expect(find.textContaining('Solo los administradores'), findsOneWidget);
    });

    testWidgets('al pegar un enlace de YouTube obtiene el título automáticamente (con espera)', (tester) async {
      final deps = TestDeps(role: UserRole.admin);
      await pumpTestApp(tester, const SermonFormScreen(), deps);

      final urlField = find.widgetWithText(TextFormField, 'Pega aquí el enlace');
      await tester.enterText(urlField, 'https://youtu.be/dQw4w9WgXc');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(urlField, 'https://youtu.be/dQw4w9WgXcQ');
      expect(deps.sermons.metadataRequests, isEmpty, reason: 'debe esperar antes de llamar a la Function');

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(deps.sermons.metadataRequests, ['https://youtu.be/dQw4w9WgXcQ']);
      expect(find.text('Prédica dominical'), findsOneWidget);
      expect(find.textContaining('YouTube · youtube.com'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardar prédica'));
      await tester.pump();
      await tester.tap(find.text('Guardar prédica'));
      await tester.pump();
      final saved = deps.sermons.saved.single;
      expect(saved.title, 'Prédica dominical');
      expect(saved.platform, VideoPlatform.youtube);
      expect(saved.externalVideoId, 'dQw4w9WgXcQ');
      expect(saved.isNew, isTrue);
    });

    testWidgets('rechaza esquemas peligrosos sin llamar al servidor', (tester) async {
      final deps = TestDeps(role: UserRole.admin);
      await pumpTestApp(tester, const SermonFormScreen(), deps);
      await tester.enterText(find.widgetWithText(TextFormField, 'Pega aquí el enlace'), 'javascript:alert(1)');
      await tester.pump(const Duration(seconds: 1));
      expect(deps.sermons.metadataRequests, isEmpty);
      expect(find.textContaining('https://'), findsWidgets);
    });

    testWidgets('si no hay título automático el administrador puede escribirlo', (tester) async {
      final deps = TestDeps(role: UserRole.admin);
      deps.sermons.metadataResult = const VideoMetadataFound(
        VideoMetadata(
          platform: VideoPlatform.other,
          domain: 'iglesia.org',
          canonicalUrl: 'https://iglesia.org/video',
          metadataAvailable: false,
        ),
      );
      await pumpTestApp(tester, const SermonFormScreen(), deps);
      await tester.enterText(find.widgetWithText(TextFormField, 'Pega aquí el enlace'), 'https://iglesia.org/video');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('No pudimos obtener el título'), findsOneWidget);
    });
  });
}
