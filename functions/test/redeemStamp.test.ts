import assert from "node:assert/strict";
import {beforeEach, describe, test} from "node:test";
import {QR_REDEEM_GRACE_MS} from "../src/constants";
import {DomainError} from "../src/core/errors";
import {Data} from "../src/core/validation";
import {
  RedeemRepository,
  RedeemTransaction,
  RedemptionIntent,
  redeemStampCore,
} from "../src/qr/redeemStampCore";
import {QrTokenPayload, signQrToken} from "../src/qr/token";
import {HOUR, storedWindow, T0, ts} from "./support/fakes";

const SECRET = "unit-test-secret-0123456789abcdef";
const UID = "user-1";

/** Almacén en memoria que imita las colecciones usadas por el canje. */
class FakeStore {
  missions = new Map<string, Data>();
  passports = new Map<string, Data>();
  redemptions = new Map<string, Data>();
  intents: RedemptionIntent[] = [];
  transactions = 0;
}

/**
 * Repositorio falso: aplica las escrituras solo si la función termina bien.
 * @param {FakeStore} store Almacén.
 * @param {Function} now Reloj.
 * @return {RedeemRepository} Repositorio.
 */
function fakeRepo(store: FakeStore, now: () => number): RedeemRepository {
  return {
    runTransaction: async (fn) => {
      store.transactions++;
      const staged: (() => void)[] = [];
      const tx: RedeemTransaction = {
        getMission: async (id) => store.missions.get(id) ?? null,
        getUserPassport: async (uid) => store.passports.get(uid) ?? null,
        getRedemption: async (uid, m) =>
          store.redemptions.get(`${uid}/${m}`) ?? null,
        createRedemption: (intent) => staged.push(() => {
          const key = `${intent.userId}/${intent.missionId}`;
          if (store.redemptions.has(key)) throw new Error("ALREADY_EXISTS");
          const redeemedAt = intent.source === "qr" ?
            ts(now()) :
            intent.redeemedAtMs === null ? null : ts(intent.redeemedAtMs);
          store.redemptions.set(key, {...intent, redeemedAt});
          store.intents.push(intent);
        }),
        recordStampConfirmed: (uid) => staged.push(() => {
          const passport = store.passports.get(uid) as Data;
          passport.stampCount = ((passport.stampCount as number) ?? 0) + 1;
        }),
      };
      const result = await fn(tx);
      staged.forEach((write) => write());
      return result;
    },
  };
}

/**
 * @param {Partial<QrTokenPayload>} overrides Cambios al payload.
 * @return {string} Token firmado.
 */
function token(overrides: Partial<QrTokenPayload> = {}): string {
  return signQrToken({
    v: 1,
    m: "m1",
    iat: T0,
    exp: T0 + 60_000,
    n: "nonce-1",
    p: "presenter-1",
    ...overrides,
  }, SECRET);
}

describe("redeemStampCore", () => {
  let store: FakeStore;
  let nowMs: number;
  const run = (tokenText: string, extra: Partial<{
    appVersion: string | null;
    platform: string | null;
  }> = {}) => redeemStampCore(
    {repo: fakeRepo(store, () => nowMs), now: () => nowMs, secret: SECRET},
    {
      uid: UID,
      token: tokenText,
      appVersion: extra.appVersion ?? "2.0.0",
      platform: extra.platform ?? "android",
    },
  );

  beforeEach(() => {
    store = new FakeStore();
    nowMs = T0 + 5_000;
    store.missions.set("m1", {
      name: "Misión Apopa",
      status: "active",
      schedule: [storedWindow(T0 - HOUR, T0 + HOUR)],
    });
    store.passports.set(UID, {fullName: "Ana", stamps: [], stampCount: 0});
  });

  test("canje válido → confirmed y crea redemption con auditoría", async () => {
    const outcome = await run(token());
    assert.deepEqual(outcome.result, {
      status: "confirmed",
      missionId: "m1",
      missionName: "Misión Apopa",
      redeemedAt: nowMs,
    });
    assert.equal(outcome.notifyStampConfirmed, true);
    assert.deepEqual(store.intents, [{
      source: "qr",
      missionId: "m1",
      userId: UID,
      missionName: "Misión Apopa",
      tokenId: "nonce-1",
      tokenIssuedAtMs: T0,
      validatedBy: "presenter-1",
      appVersion: "2.0.0",
      platform: "android",
    }]);
    assert.equal(store.passports.get(UID)?.stampCount, 1);
  });

  test("respeta notificationPrefs.stampConfirmed = false", async () => {
    store.passports.set(UID, {notificationPrefs: {stampConfirmed: false}});
    const outcome = await run(token());
    assert.equal(outcome.result.status, "confirmed");
    assert.equal(outcome.notifyStampConfirmed, false);
  });

  test("segundo canje → alreadyRedeemed sin duplicar", async () => {
    await run(token());
    nowMs += 10_000;
    const outcome = await run(token({n: "otro-nonce"}));
    assert.deepEqual(outcome.result, {
      status: "alreadyRedeemed",
      missionId: "m1",
      missionName: "Misión Apopa",
      redeemedAt: T0 + 5_000,
    });
    assert.equal(outcome.notifyStampConfirmed, false);
    assert.equal(store.intents.length, 1);
    assert.equal(store.passports.get(UID)?.stampCount, 1);
  });

  test("sello en el arreglo heredado → alreadyRedeemed + migra", async () => {
    const legacyDate = T0 - 30 * 24 * HOUR;
    store.passports.set(UID, {
      stamps: [{stampId: "m1", dateObtained: ts(legacyDate)}],
      stampCount: 1,
    });
    const outcome = await run(token());
    assert.deepEqual(outcome.result, {
      status: "alreadyRedeemed",
      missionId: "m1",
      missionName: "Misión Apopa",
      redeemedAt: legacyDate,
    });
    assert.deepEqual(store.intents, [{
      source: "legacy_migration",
      missionId: "m1",
      userId: UID,
      missionName: "Misión Apopa",
      redeemedAtMs: legacyDate,
    }]);
    assert.equal(store.passports.get(UID)?.stampCount, 1);
  });

  test("fecha heredada corrupta → redeemedAt null", async () => {
    store.passports.set(UID, {
      stamps: [{stampId: "m1", dateObtained: "2024-05-01"}],
    });
    const outcome = await run(token());
    assert.equal(outcome.result.status, "alreadyRedeemed");
    assert.equal(
      (outcome.result as {redeemedAt: number | null}).redeemedAt,
      null,
    );
    assert.equal(
      (store.intents[0] as {redeemedAtMs: number | null}).redeemedAtMs,
      null,
    );
  });

  test("misión inactiva o borrador → inactive", async () => {
    for (const status of ["inactive", "draft"]) {
      store.missions.set("m1", {
        name: "Misión Apopa",
        status,
        active: true,
        schedule: [storedWindow(T0 - HOUR, T0 + HOUR)],
      });
      const outcome = await run(token());
      assert.deepEqual(outcome.result, {
        status: "inactive",
        missionName: "Misión Apopa",
      });
    }
    assert.equal(store.intents.length, 0);
  });

  test("misión heredada sin status pero active=true se acepta", async () => {
    store.missions.set("m1", {
      name: "Heredada",
      active: true,
      schedule: [storedWindow(T0 - HOUR, T0 + HOUR)],
    });
    const outcome = await run(token());
    assert.equal(outcome.result.status, "confirmed");
  });

  test("el horario se valida con iat del token, no con la hora actual",
    async () => {
      const end = T0 + HOUR;
      store.missions.set("m1", {
        name: "Misión Apopa",
        status: "active",
        schedule: [storedWindow(T0 - HOUR, end)],
      });
      // Emitido 1 ms antes del cierre y canjeado después: válido.
      nowMs = end + 20_000;
      const inside = await run(token({iat: end - 1, exp: end - 1 + 60_000}));
      assert.equal(inside.result.status, "confirmed");

      // Emitido después del cierre: fuera de horario aunque siga vigente.
      store.redemptions.clear();
      const outside = await run(token({iat: end, exp: end + 60_000}));
      assert.deepEqual(outside.result, {
        status: "outsideSchedule",
        missionName: "Misión Apopa",
      });
    });

  test("misión inexistente → notFound", async () => {
    const outcome = await run(token({m: "no-existe"}));
    assert.deepEqual(outcome.result, {status: "notFound"});
  });

  test("token vencido → expired sin abrir transacción", async () => {
    nowMs = T0 + 60_000 + QR_REDEEM_GRACE_MS + 1;
    const outcome = await run(token());
    assert.deepEqual(outcome.result, {status: "expired"});
    assert.equal(store.transactions, 0);
  });

  test("dentro de la gracia todavía se acepta", async () => {
    nowMs = T0 + 60_000 + QR_REDEEM_GRACE_MS;
    assert.equal((await run(token())).result.status, "confirmed");
  });

  test("firma inválida o token mal formado → invalid", async () => {
    const forged = signQrToken({
      v: 1, m: "m1", iat: T0, exp: T0 + 60_000, n: "x", p: "y",
    }, "otro-secreto-0123456789abcdef");
    assert.deepEqual((await run(forged)).result, {status: "invalid"});
    assert.deepEqual((await run("PMCMO1.abc")).result, {status: "invalid"});
    assert.deepEqual((await run("")).result, {status: "invalid"});
    assert.equal(store.transactions, 0);
  });

  test("QR heredado (stampId plano) → invalid", async () => {
    const outcome = await run("ec612cb9-1a2b-4c3d-9e8f-001122334455");
    assert.deepEqual(outcome.result, {status: "invalid"});
    assert.deepEqual((await run("m1")).result, {status: "invalid"});
    assert.equal(store.transactions, 0);
  });

  test("sin perfil → failed-precondition y nada se escribe", async () => {
    store.passports.clear();
    await assert.rejects(run(token()), (error: unknown) => {
      assert.ok(error instanceof DomainError);
      assert.equal(error.code, "failed-precondition");
      assert.equal(error.message, "Completa tu perfil primero");
      return true;
    });
    assert.equal(store.redemptions.size, 0);
  });
});
