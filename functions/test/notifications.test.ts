import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {
  shouldAnnounceMission,
  shouldAnnounceSermon,
} from "../src/notifications/announceRules";
import {findUpcomingReminders} from "../src/notifications/reminders";
import {HOUR, MINUTE, storedWindow, T0, ts} from "./support/fakes";

describe("findUpcomingReminders", () => {
  const missions = [
    {id: "a", data: {
      name: "Apopa",
      status: "active",
      schedule: [
        storedWindow(T0, T0 + HOUR),
        storedWindow(T0 + 30 * MINUTE + HOUR, T0 + 3 * HOUR),
      ],
    }},
    {id: "b", data: {
      name: "Borrador",
      status: "draft",
      schedule: [storedWindow(T0 + 10 * MINUTE, T0 + HOUR)],
    }},
    {id: "c", data: {
      name: "Heredada",
      active: true,
      schedule: [storedWindow(T0 + HOUR, T0 + 2 * HOUR)],
    }},
  ];

  test("ventanas que inician en (now, now + 1 h]", () => {
    const result = findUpcomingReminders(missions, T0);
    assert.deepEqual(result, [{
      missionId: "c",
      missionName: "Heredada",
      startMs: T0 + HOUR,
      key: `c_${T0 + HOUR}`,
    }]);
  });

  test("límites: inicio == now excluido, now + 1 h incluido", () => {
    const keys = findUpcomingReminders(missions, T0 - 1).map((r) => r.key);
    assert.deepEqual(keys, [`a_${T0}`]);
    const later = findUpcomingReminders(missions, T0 + 30 * MINUTE);
    assert.deepEqual(later.map((r) => r.missionId).sort(), ["a", "c"]);
  });
});

describe("reglas de anuncio", () => {
  test("misión nueva activa o borrador → activa se anuncia", () => {
    assert.equal(shouldAnnounceMission(undefined, {status: "active"}), true);
    assert.equal(
      shouldAnnounceMission({status: "draft"}, {status: "active"}),
      true,
    );
  });

  test("no se anuncia si ya se anunció, no está activa o ya lo estaba", () => {
    assert.equal(
      shouldAnnounceMission(undefined, {status: "active", announcedAt: ts(T0)}),
      false,
    );
    assert.equal(shouldAnnounceMission(undefined, {status: "draft"}), false);
    // La migración agrega status a una misión heredada activa: sin aviso.
    assert.equal(
      shouldAnnounceMission({active: true}, {active: true, status: "active"}),
      false,
    );
  });

  test("prédicas: activas, no borradas y sin announcedAt", () => {
    assert.equal(shouldAnnounceSermon({active: true}), true);
    assert.equal(shouldAnnounceSermon({active: true, deleted: true}), false);
    assert.equal(shouldAnnounceSermon({active: false}), false);
    assert.equal(
      shouldAnnounceSermon({active: true, announcedAt: ts(T0)}),
      false,
    );
  });
});
