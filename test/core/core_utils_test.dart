import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/core/utils/business_time.dart';
import 'package:pasaporte_misionero_cmo/core/utils/image_rules.dart';
import 'package:pasaporte_misionero_cmo/core/utils/text_utils.dart';
import 'package:pasaporte_misionero_cmo/core/utils/url_utils.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(initTestLocale);

  group('BusinessTime (America/El_Salvador, UTC−6)', () {
    test('convierte la hora de pared a un instante UTC', () {
      expect(BusinessTime.fromWallClock(2026, 10, 4, 19, 30), DateTime.utc(2026, 10, 5, 1, 30));
    });

    test('ida y vuelta conserva la hora de pared', () {
      final instant = BusinessTime.fromWallClock(2026, 12, 31, 23, 59);
      final wall = BusinessTime.toWallClock(instant);
      expect((wall.year, wall.month, wall.day, wall.hour, wall.minute), (2026, 12, 31, 23, 59));
    });

    test('formatea en español sin depender de la zona del teléfono', () {
      final instant = DateTime.utc(2026, 10, 5, 1, 30);
      expect(BusinessTime.formatLongDate(instant), 'domingo 4 de octubre de 2026');
      expect(BusinessTime.formatCompact(instant), '04/10/2026 19:30');
    });
  });

  group('UrlUtils.isSafeHttpsUrl', () {
    test('acepta https válidas', () {
      expect(UrlUtils.isSafeHttpsUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlUtils.isSafeHttpsUrl(' https://youtu.be/dQw4w9WgXcQ '), isTrue);
    });

    test('rechaza esquemas peligrosos o URLs inválidas', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'http://youtube.com/watch?v=x',
        'data:text/html,hola',
        'https://usuario:clave@ejemplo.com',
        'https://localhost',
        'no es una url',
        '',
        null,
        'https://${'a' * 2100}.com',
      ]) {
        expect(UrlUtils.isSafeHttpsUrl(bad), isFalse, reason: '$bad');
      }
    });

    test('domainOf quita www', () {
      expect(UrlUtils.domainOf('https://www.youtube.com/watch?v=1'), 'youtube.com');
    });
  });

  group('text utils', () {
    test('initialsFor', () {
      expect(initialsFor('María José López'), 'MJ');
      expect(initialsFor('  ana  '), 'AN');
      expect(initialsFor('X'), 'X');
      expect(initialsFor(''), 'CM');
    });

    test('normalizeUsername quita espacios y pasa a minúsculas', () {
      expect(normalizeUsername(' Mateo CMO '), 'mateocmo');
    });
  });

  group('image rules', () {
    test('tipo de imagen por extensión o MIME reportado', () {
      expect(imageContentTypeFor('foto.JPG'), 'image/jpeg');
      expect(imageContentTypeFor('foto.png'), 'image/png');
      expect(imageContentTypeFor('x', reported: 'image/webp'), 'image/webp');
      expect(imageContentTypeFor('documento.pdf'), isNull);
      expect(imageContentTypeFor('x.gif', reported: 'image/gif'), isNull);
    });
  });
}
