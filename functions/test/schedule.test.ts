import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {ValidationError} from "../src/core/errors";
import {
  findActiveMissions,
  isMissionActive,
  isWithinAnyWindow,
  missionStatusOf,
  parseStoredSchedule,
  validateSchedules,
} from "../src/missions/schedule";
import {HOUR, storedWindow, T0, ts} from "./support/fakes";

/**
 * @param {Function} fn Función que debe fallar.
 * @param {RegExp} message Mensaje esperado.
 */
function assertScheduleError(fn: () => unknown, message?: RegExp) {
  assert.throws(fn, (error: unknown) => {
    assert.ok(error instanceof ValidationError);
    assert.equal(error.field, "schedules");
    if (message) assert.match(error.message, message);
    return true;
  });
}

describe("validateSchedules", () => {
  test("ordena por inicio y acepta ventanas contiguas", () => {
    const result = validateSchedules([
      {start: T0 + 2 * HOUR, end: T0 + 3 * HOUR},
      {start: T0, end: T0 + HOUR},
      {start: T0 + HOUR, end: T0 + 2 * HOUR},
    ]);
    assert.deepEqual(result, [
      {startMs: T0, endMs: T0 + HOUR},
      {startMs: T0 + HOUR, endMs: T0 + 2 * HOUR},
      {startMs: T0 + 2 * HOUR, endMs: T0 + 3 * HOUR},
    ]);
  });

  test("start >= end se rechaza", () => {
    assertScheduleError(
      () => validateSchedules([{start: T0, end: T0}]),
      /anterior/,
    );
    assertScheduleError(() => validateSchedules([{start: T0 + 1, end: T0}]));
  });

  test("solapamientos se rechazan (también desordenados)", () => {
    assertScheduleError(() => validateSchedules([
      {start: T0 + HOUR, end: T0 + 3 * HOUR},
      {start: T0, end: T0 + 2 * HOUR},
    ]), /solaparse/);
  });

  test("máximo 20 ventanas", () => {
    const windows = (n: number) => Array.from({length: n}, (_, i) => ({
      start: T0 + i * HOUR,
      end: T0 + i * HOUR + 30 * 60_000,
    }));
    assert.equal(validateSchedules(windows(20)).length, 20);
    assertScheduleError(() => validateSchedules(windows(21)), /20/);
  });

  test("NaN, Infinity, strings u objetos inválidos se rechazan", () => {
    const bad: unknown[] = [
      [{start: NaN, end: T0}],
      [{start: T0, end: Infinity}],
      [{start: String(T0), end: T0 + HOUR}],
      [{start: T0}],
      [null],
      [[T0, T0 + HOUR]],
      [{start: Date.UTC(1990, 0, 1), end: Date.UTC(1990, 0, 2)}],
    ];
    for (const input of bad) {
      assertScheduleError(() => validateSchedules(input));
    }
  });

  test("lista requerida y mínimo configurable", () => {
    assertScheduleError(() => validateSchedules("x"), /lista/);
    assertScheduleError(() => validateSchedules([]), /al menos/);
    assert.deepEqual(validateSchedules([], {minWindows: 0}), []);
  });

  test("trunca milisegundos fraccionarios", () => {
    const [w] = validateSchedules([{start: T0 + 0.7, end: T0 + HOUR + 0.2}]);
    assert.deepEqual(w, {startMs: T0, endMs: T0 + HOUR});
  });
});

describe("parseStoredSchedule / isWithinAnyWindow", () => {
  test("descarta entradas corruptas y ordena", () => {
    const parsed = parseStoredSchedule([
      storedWindow(T0 + HOUR, T0 + 2 * HOUR),
      {start: "2026-01-01", end: ts(T0)},
      {start: ts(T0 + 5), end: ts(T0)},
      null,
      storedWindow(T0, T0 + 30),
    ]);
    assert.deepEqual(parsed, [
      {startMs: T0, endMs: T0 + 30},
      {startMs: T0 + HOUR, endMs: T0 + 2 * HOUR},
    ]);
    assert.deepEqual(parseStoredSchedule(undefined), []);
  });

  test("inicio inclusivo, fin exclusivo", () => {
    const windows = [{startMs: T0, endMs: T0 + HOUR}];
    assert.equal(isWithinAnyWindow(windows, T0), true);
    assert.equal(isWithinAnyWindow(windows, T0 + HOUR - 1), true);
    assert.equal(isWithinAnyWindow(windows, T0 + HOUR), false);
    assert.equal(isWithinAnyWindow(windows, T0 - 1), false);
    assert.equal(isWithinAnyWindow([], T0), false);
  });
});

describe("estado de misión", () => {
  test("status tiene prioridad sobre active heredado", () => {
    assert.equal(isMissionActive({status: "active"}), true);
    assert.equal(isMissionActive({status: "inactive", active: true}), false);
    assert.equal(isMissionActive({status: "draft", active: true}), false);
    assert.equal(isMissionActive({active: true}), true);
    assert.equal(isMissionActive({active: false}), false);
    assert.equal(isMissionActive({}), false);
    assert.equal(missionStatusOf({active: true}), "active");
    assert.equal(missionStatusOf({}), "inactive");
    assert.equal(missionStatusOf({status: "raro"}), null);
  });
});

describe("findActiveMissions", () => {
  const window = [storedWindow(T0 - HOUR, T0 + HOUR)];
  const missions = [
    {id: "draft", data: {name: "Borrador", status: "draft", schedule: window}},
    {id: "off", data: {name: "Inactiva", status: "inactive", schedule: window}},
    {id: "legacy", data: {
      name: "Zacatecoluca",
      active: true,
      schedule: window,
    }},
    {id: "legacyOff", data: {name: "Vieja", active: false, schedule: window}},
    {id: "late", data: {
      name: "Futura",
      status: "active",
      schedule: [storedWindow(T0 + HOUR, T0 + 2 * HOUR)],
    }},
    {id: "ok", data: {name: "Apopa", status: "active", schedule: window}},
    {id: "noSchedule", data: {name: "Sin horario", status: "active"}},
  ];

  test("excluye borradores, inactivas, fuera de horario; incluye heredadas",
    () => {
      const result = findActiveMissions(missions, T0);
      assert.deepEqual(result.map((m) => m.id), ["ok", "legacy"]);
      assert.equal(result[0].name, "Apopa");
    });

  test("fuera de toda ventana no hay misiones activas", () => {
    assert.deepEqual(findActiveMissions(missions, T0 + 5 * HOUR), []);
  });
});
