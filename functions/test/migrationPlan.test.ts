import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {Data, isPlainObject} from "../src/core/validation";
import {
  MigrationPlan,
  missingDefaults,
  planMigration,
  plannedWriteCount,
  PlannerMission,
  PlannerUser,
} from "../src/migrations/plan";
import {legacyRedemptionDoc} from "../src/passport/redemptionDocs";
import {T0, ts} from "./support/fakes";

const DAY = 86_400_000;

/**
 * Datos de prueba que imitan la base heredada.
 * @return {object} Usuarios y misiones.
 */
function fixture(): {users: PlannerUser[]; missions: PlannerMission[]} {
  return {
    missions: [
      {id: "m1", data: {name: "Apopa", active: true}},
      {id: "m2", data: {name: "Soyapango", active: false}},
      {id: "m3", data: {name: "Nueva", status: "draft", active: false}},
    ],
    users: [
      {
        uid: "admin1",
        data: {
          fullName: "Admin",
          isAdmin: true,
          stamps: [
            {stampId: "m1", dateObtained: ts(T0 - 2 * DAY)},
            {stampId: "m2", dateObtained: "2024-01-01"},
            {stampId: "fantasma", dateObtained: ts(T0 - DAY)},
            {stampId: "m1", dateObtained: ts(T0 - 9 * DAY)},
            {foo: "sin stampId"},
          ],
        },
        redemptionIds: ["m3"],
        authUser: {claims: {}},
      },
      {
        uid: "presenter1",
        data: {canShowQR: true, stamps: [], communityVisible: false},
        redemptionIds: [],
        authUser: {claims: {otro: "x"}},
      },
      {
        uid: "alreadyAdmin",
        data: {canShowQR: true, notificationPrefs: {newMission: false}},
        redemptionIds: [],
        authUser: {claims: {role: "admin"}},
      },
      {
        uid: "keepPresenter",
        data: {isAdmin: false, canShowQR: false, stampCount: 0},
        redemptionIds: [],
        authUser: {claims: {role: "qrPresenter"}},
      },
      {
        uid: "ghostAuth",
        data: {isAdmin: true, stamps: [{stampId: "m1", dateObtained: ts(T0)}]},
        redemptionIds: [],
        authUser: null,
      },
    ],
  };
}

/**
 * Aplica set(..., {merge: true}) con fusión profunda de mapas.
 * @param {Data} target Documento.
 * @param {Data} patch Cambios.
 */
function mergeDeep(target: Data, patch: Data): void {
  for (const [key, value] of Object.entries(patch)) {
    if (isPlainObject(value) && isPlainObject(target[key])) {
      mergeDeep(target[key] as Data, value);
    } else {
      target[key] = isPlainObject(value) ? {...value} : value;
    }
  }
}

/**
 * Simula en memoria lo que haría runMigrations con el plan.
 * @param {object} state Usuarios y misiones (se modifican).
 * @param {MigrationPlan} plan Plan.
 */
function applyInMemory(
  state: {users: PlannerUser[]; missions: PlannerMission[]},
  plan: MigrationPlan,
): void {
  const users = new Map(state.users.map((u) => [u.uid, u]));
  for (const update of plan.claimUpdates) {
    const user = users.get(update.uid) as PlannerUser;
    user.authUser = {claims: update.claims};
  }
  for (const intent of plan.redemptionCreates) {
    const user = users.get(intent.userId) as PlannerUser;
    assert.ok(!user.redemptionIds.includes(intent.missionId), "create()");
    user.redemptionIds.push(intent.missionId);
  }
  for (const patch of plan.passportPatches) {
    const user = users.get(patch.uid) as PlannerUser;
    mergeDeep(user.data, patch.set);
    if (patch.incrementRoleVersion) {
      user.data.roleVersion = ((user.data.roleVersion as number) ?? 0) + 1;
    }
  }
  for (const update of plan.missionStatusUpdates) {
    const mission = state.missions.find((m) => m.id === update.missionId);
    (mission as PlannerMission).data.status = update.status;
  }
}

describe("planMigration – roles", () => {
  const plan = planMigration(fixture().users, fixture().missions);

  test("isAdmin → admin y canShowQR → qrPresenter (conservando claims)", () => {
    assert.deepEqual(plan.claimUpdates, [
      {uid: "admin1", role: "admin", claims: {role: "admin"}},
      {
        uid: "presenter1",
        role: "qrPresenter",
        claims: {otro: "x", role: "qrPresenter"},
      },
    ]);
    assert.deepEqual(plan.stats.claimsToSet, {admin: 1, qrPresenter: 1});
  });

  test("nunca baja a un admin ni quita qrPresenter", () => {
    const uids = plan.claimUpdates.map((c) => c.uid);
    assert.ok(!uids.includes("alreadyAdmin"));
    assert.ok(!uids.includes("keepPresenter"));
    const mirror = plan.passportPatches.find((p) => p.uid === "alreadyAdmin");
    assert.equal(mirror?.set.role, "admin");
    const keep = plan.passportPatches.find((p) => p.uid === "keepPresenter");
    assert.equal(keep?.set.role, "qrPresenter");
  });

  test("usuarios sin cuenta en Auth se cuentan y no reciben claims", () => {
    assert.equal(plan.stats.authUsersMissing, 1);
    const ghost = plan.passportPatches.find((p) => p.uid === "ghostAuth");
    assert.equal(ghost?.set.role, undefined);
    assert.equal(ghost?.incrementRoleVersion, false);
  });

  test("el espejo del rol aumenta roleVersion", () => {
    const admin = plan.passportPatches.find((p) => p.uid === "admin1");
    assert.equal(admin?.set.role, "admin");
    assert.equal(admin?.incrementRoleVersion, true);
  });
});

describe("planMigration – canjes heredados", () => {
  const plan = planMigration(fixture().users, fixture().missions);

  test("crea un canje por misión, con la fecha válida más antigua", () => {
    const admin = plan.redemptionCreates.filter((r) => r.userId === "admin1");
    assert.deepEqual(admin, [
      {
        source: "legacy_migration",
        missionId: "m1",
        userId: "admin1",
        missionName: "Apopa",
        redeemedAtMs: T0 - 9 * DAY,
      },
      {
        source: "legacy_migration",
        missionId: "m2",
        userId: "admin1",
        missionName: "Soyapango",
        redeemedAtMs: null,
      },
      {
        source: "legacy_migration",
        missionId: "fantasma",
        userId: "admin1",
        missionName: "Misión",
        redeemedAtMs: T0 - DAY,
      },
    ]);
  });

  test("estadísticas de calidad de datos", () => {
    const s = plan.stats;
    assert.equal(s.users, 5);
    assert.equal(s.usersWithLegacyStamps, 2);
    assert.equal(s.legacyEntries, 5);
    assert.equal(s.invalidLegacyEntries, 1);
    assert.equal(s.unknownMissionRefs, 1);
    assert.equal(s.corruptedDates, 1);
    assert.equal(s.redemptionsToCreate, 4);
    assert.equal(s.redemptionsExisting, 0);
  });

  test("fecha corrupta → redeemedAt null + legacyDateMissing", () => {
    const corrupted = plan.redemptionCreates.find((r) => r.missionId === "m2");
    const doc = legacyRedemptionDoc(
      corrupted as Parameters<typeof legacyRedemptionDoc>[0],
    );
    assert.equal(doc.redeemedAt, null);
    assert.equal(doc.legacyDateMissing, true);
    assert.equal(doc.source, "legacy_migration");
    assert.equal(doc.status, "confirmed");
    for (const field of [
      "tokenId",
      "tokenIssuedAt",
      "validatedBy",
      "appVersion",
      "platform",
    ]) {
      assert.equal(doc[field], null);
    }
    const valid = plan.redemptionCreates.find((r) => r.missionId === "m1");
    const validDoc = legacyRedemptionDoc(
      valid as Parameters<typeof legacyRedemptionDoc>[0],
    );
    assert.equal(validDoc.legacyDateMissing, false);
    assert.equal(validDoc.redeemedAt.toMillis(), T0 - 9 * DAY);
  });

  test("stampCount = unión de canjes existentes y heredados", () => {
    const admin = plan.passportPatches.find((p) => p.uid === "admin1");
    assert.equal(admin?.set.stampCount, 4);
  });
});

describe("planMigration – valores por defecto y misiones", () => {
  test("solo agrega campos faltantes", () => {
    assert.deepEqual(missingDefaults({}), {
      communityVisible: true,
      showNationality: false,
      showCell: true,
      notificationPrefs: {
        newMission: true,
        missionReminder: true,
        newSermon: true,
        stampConfirmed: true,
      },
    });
    assert.deepEqual(missingDefaults({
      communityVisible: false,
      showNationality: true,
      showCell: false,
      notificationPrefs: {newMission: false},
    }), {
      notificationPrefs: {
        missionReminder: true,
        newSermon: true,
        stampConfirmed: true,
      },
    });
    assert.deepEqual(missingDefaults({
      communityVisible: true,
      showNationality: false,
      showCell: true,
      notificationPrefs: "corrupto",
    }), {});
  });

  test("no sobrescribe valores existentes", () => {
    const plan = planMigration(fixture().users, fixture().missions);
    const presenter = plan.passportPatches.find((p) => p.uid === "presenter1");
    assert.equal(presenter?.set.communityVisible, undefined);
    const admin = plan.passportPatches.find((p) => p.uid === "alreadyAdmin");
    assert.deepEqual(admin?.set.notificationPrefs, {
      missionReminder: true,
      newSermon: true,
      stampConfirmed: true,
    });
  });

  test("misiones sin status reciben active/inactive según active", () => {
    const plan = planMigration(fixture().users, fixture().missions);
    assert.deepEqual(plan.missionStatusUpdates, [
      {missionId: "m1", status: "active"},
      {missionId: "m2", status: "inactive"},
    ]);
    assert.equal(plan.stats.missionsStatusSet, 2);
  });
});

describe("planMigration – idempotencia", () => {
  test("aplicar el plan y volver a planificar no produce escrituras", () => {
    const state = fixture();
    const first = planMigration(state.users, state.missions);
    assert.ok(plannedWriteCount(first) > 0);
    applyInMemory(state, first);

    const second = planMigration(state.users, state.missions);
    assert.equal(plannedWriteCount(second), 0);
    assert.equal(second.stats.redemptionsToCreate, 0);
    assert.equal(second.stats.redemptionsExisting, 4);
    assert.deepEqual(second.stats.claimsToSet, {admin: 0, qrPresenter: 0});
    assert.equal(second.stats.userDefaultsUpdated, 0);
    assert.equal(second.stats.missionsStatusSet, 0);

    const third = planMigration(state.users, state.missions);
    assert.deepEqual(third, second);
  });

  test("tras migrar, los claims de admin siguen intactos", () => {
    const state = fixture();
    applyInMemory(state, planMigration(state.users, state.missions));
    const admin = state.users.find((u) => u.uid === "alreadyAdmin");
    assert.deepEqual(admin?.authUser?.claims, {role: "admin"});
    const keep = state.users.find((u) => u.uid === "keepPresenter");
    assert.deepEqual(keep?.authUser?.claims, {role: "qrPresenter"});
  });

  test("nunca planifica borrar: los parches no contienen null/undefined",
    () => {
      const plan = planMigration(fixture().users, fixture().missions);
      for (const patch of plan.passportPatches) {
        for (const value of Object.values(patch.set)) {
          assert.ok(value !== null && value !== undefined);
        }
      }
    });
});
