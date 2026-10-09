import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/service_photo.dart';
import 'package:pasaporte_misionero_cmo/domain/models/stamp_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/missions/mission_detail_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/passport/widgets/stamp_list.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/sermons/sermon_photos_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/sermons/sermons_tab.dart';

import '../helpers/test_app.dart';

final _sermon = Sermon(
  id: 's1',
  sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  title: 'Culto de misiones',
  platform: VideoPlatform.youtube,
  domain: 'youtube.com',
  publishedAt: DateTime.utc(2026, 10, 4, 18),
);

const _photo = ServicePhoto(id: 'culto_1', url: '', originalUrl: '', storagePath: 'sermon_photos/s1/culto_1.jpg');

void main() {
  setUpAll(initTestLocale);

  group('Fotos del culto de una prédica', () {
    testWidgets('todos ven el botón "Ver fotos" y abre el álbum de la prédica', (tester) async {
      final deps = TestDeps()..sermons.sermons = [_sermon];
      await pumpTestApp(tester, const Scaffold(body: SermonsTab()), deps);
      await tester.tap(find.text('Ver fotos'));
      await tester.pumpAndSettle();
      expect(find.byType(SermonPhotosScreen), findsOneWidget);
      expect(find.text('Aún no hay fotos de este culto'), findsOneWidget);
      expect(find.text('Agregar fotos'), findsNothing);
    });

    testWidgets('solo el administrador puede agregar fotos', (tester) async {
      await pumpTestApp(tester, SermonPhotosScreen(sermon: _sermon), TestDeps(role: UserRole.admin));
      expect(find.text('Agregar fotos'), findsOneWidget);
      await pumpTestApp(tester, SermonPhotosScreen(sermon: _sermon), TestDeps(role: UserRole.qrPresenter));
      expect(find.text('Agregar fotos'), findsNothing);
    });

    testWidgets('una foto se guarda en la galería del teléfono', (tester) async {
      final deps = TestDeps();
      deps.servicePhotos.albums[const PhotoAlbum.sermon('s1')] = [_photo];
      await pumpTestApp(tester, SermonPhotosScreen(sermon: _sermon), deps);
      await tester.tap(find.bySemanticsLabel(RegExp('Foto del culto 1')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar foto'), findsNothing, reason: 'un usuario normal no puede eliminar');
      await tester.tap(find.text('Guardar en la galería'));
      await tester.pumpAndSettle();
      expect(deps.photoSaver.saved, hasLength(1));
      expect(find.textContaining('Foto guardada en tu galería'), findsOneWidget);
    });

    testWidgets('si no hay permiso de galería se explica cómo darlo', (tester) async {
      final deps = TestDeps()..photoSaver.granted = false;
      deps.servicePhotos.albums[const PhotoAlbum.sermon('s1')] = [_photo];
      await pumpTestApp(tester, SermonPhotosScreen(sermon: _sermon), deps);
      await tester.tap(find.bySemanticsLabel(RegExp('Foto del culto 1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en la galería'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permite el acceso a la galería'), findsOneWidget);
    });
  });

  testWidgets('tocar un sello abre su misión', (tester) async {
    final deps = TestDeps()
      ..missions.missions = [const Mission(id: 'm1', name: 'Honduras', isoCode: 'HN', status: MissionStatus.active)];
    await pumpTestApp(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => const StampList(
            stamps: AsyncData([StampRedemption(missionId: 'm1', source: RedemptionSource.qr)]),
          ),
        ),
      ),
      deps,
    );
    await tester.tap(find.byType(StampTile));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailScreen), findsOneWidget);
    expect(find.text('Honduras'), findsWidgets);
  });
}
