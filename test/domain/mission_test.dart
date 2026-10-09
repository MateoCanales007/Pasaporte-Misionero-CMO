import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/use_cases/validate_mission_schedules.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 4, 15);
  MissionSchedule window(int startHour, int endHour) => MissionSchedule(
    start: t0.add(Duration(hours: startHour)),
    end: t0.add(Duration(hours: endHour)),
  );

  Mission mission({MissionStatus status = MissionStatus.active, List<MissionSchedule>? schedules}) =>
      Mission(id: 'm1', name: 'Guatemala', isoCode: 'GT', status: status, schedules: schedules ?? [window(0, 2)]);

  group('MissionSchedule', () {
    test('contains: inicio inclusivo, fin exclusivo', () {
      final w = window(0, 2);
      expect(w.contains(t0), isTrue);
      expect(w.contains(t0.add(const Duration(hours: 1))), isTrue);
      expect(w.contains(t0.add(const Duration(hours: 2))), isFalse);
      expect(w.contains(t0.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('overlaps detecta cruces y permite ventanas contiguas', () {
      expect(window(0, 2).overlaps(window(1, 3)), isTrue);
      expect(window(0, 2).overlaps(window(2, 4)), isFalse);
      expect(window(0, 5).overlaps(window(1, 2)), isTrue);
    });
  });

  group('MissionStatus.parse', () {
    test('lee el estado nuevo', () {
      expect(MissionStatus.parse('draft'), MissionStatus.draft);
      expect(MissionStatus.parse('active'), MissionStatus.active);
      expect(MissionStatus.parse('inactive'), MissionStatus.inactive);
    });

    test('documentos heredados sin status usan el booleano active', () {
      expect(MissionStatus.parse(null, legacyActive: true), MissionStatus.active);
      expect(MissionStatus.parse(null, legacyActive: false), MissionStatus.inactive);
      expect(MissionStatus.parse(null), MissionStatus.inactive);
    });
  });

  group('Mission.phaseAt', () {
    test('abierta durante una ventana si está activa', () {
      expect(mission().phaseAt(t0.add(const Duration(minutes: 30))), MissionPhase.open);
    });

    test('inactiva no se abre aunque esté en horario', () {
      final m = mission(status: MissionStatus.inactive);
      expect(m.isOpenAt(t0.add(const Duration(minutes: 30))), isFalse);
      expect(m.phaseAt(t0.add(const Duration(minutes: 30))), MissionPhase.inactive);
    });

    test('próxima antes de iniciar y finalizada después', () {
      final m = mission();
      expect(m.phaseAt(t0.subtract(const Duration(hours: 1))), MissionPhase.upcoming);
      expect(m.phaseAt(t0.add(const Duration(hours: 3))), MissionPhase.finished);
    });

    test('borrador siempre es borrador', () {
      expect(mission(status: MissionStatus.draft).phaseAt(t0), MissionPhase.draft);
    });

    test('nextWindow devuelve la ventana en curso o la siguiente', () {
      final m = mission(schedules: [window(5, 6), window(0, 2)]);
      expect(m.nextWindow(t0.add(const Duration(hours: 1))), window(0, 2));
      expect(m.nextWindow(t0.add(const Duration(hours: 3))), window(5, 6));
      expect(m.nextWindow(t0.add(const Duration(hours: 7))), isNull);
    });
  });

  group('ValidateMissionSchedules', () {
    test('sin problemas para ventanas válidas sin cruces', () {
      expect(ValidateMissionSchedules.call([window(0, 2), window(3, 4)], requireAtLeastOne: true), isEmpty);
    });

    test('inicio igual o posterior al fin es un error', () {
      final issues = ValidateMissionSchedules.call([window(2, 2), window(5, 3)], requireAtLeastOne: true);
      expect(issues.map((i) => i.index), [0, 1]);
      expect(issues.first.message, contains('anterior'));
    });

    test('detecta horarios superpuestos aunque estén desordenados', () {
      final issues = ValidateMissionSchedules.call([window(3, 6), window(0, 4)], requireAtLeastOne: true);
      expect(issues, hasLength(1));
      expect(issues.single.index, 1);
      expect(issues.single.message, contains('cruza'));
    });

    test('una misión activa necesita al menos un horario', () {
      expect(ValidateMissionSchedules.call([], requireAtLeastOne: true), hasLength(1));
      expect(ValidateMissionSchedules.call([], requireAtLeastOne: false), isEmpty);
    });

    test('máximo 20 ventanas', () {
      final many = [for (var i = 0; i < 21; i++) window(i * 2, i * 2 + 1)];
      expect(ValidateMissionSchedules.call(many, requireAtLeastOne: true).single.message, contains('20'));
    });
  });
}
