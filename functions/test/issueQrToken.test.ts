import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {decideQrIssue} from "../src/qr/issueQrTokenCore";
import {verifyQrToken} from "../src/qr/token";
import {HOUR, storedWindow, T0} from "./support/fakes";

const SECRET = "unit-test-secret-0123456789abcdef";
const ctx = {nowMs: T0, secret: SECRET, presenterUid: "pres-1", nonce: "n1"};
const open = [storedWindow(T0 - HOUR, T0 + HOUR)];

describe("decideQrIssue", () => {
  test("sin misiones activas → noActiveMission", () => {
    assert.deepEqual(decideQrIssue([], null, ctx), {status: "noActiveMission"});
    const closed = [{id: "a", data: {
      name: "A",
      status: "active",
      schedule: [storedWindow(T0 + HOUR, T0 + 2 * HOUR)],
    }}];
    assert.deepEqual(decideQrIssue(closed, null, ctx), {
      status: "noActiveMission",
    });
  });

  test("una misión activa → token firmado de 60 s", () => {
    const missions = [
      {id: "m1", data: {name: "Ilopango", status: "active", schedule: open}},
      {id: "m2", data: {name: "Draft", status: "draft", schedule: open}},
    ];
    const result = decideQrIssue(missions, null, ctx);
    assert.equal(result.status, "ok");
    if (result.status !== "ok") return;
    assert.equal(result.missionId, "m1");
    assert.equal(result.missionName, "Ilopango");
    assert.equal(result.issuedAt, T0);
    assert.equal(result.expiresAt, T0 + 60_000);
    assert.equal(result.refreshAfterMs, 30_000);
    const verified = verifyQrToken(result.token, SECRET, T0);
    assert.deepEqual(verified, {
      ok: true,
      payload: {
        v: 1,
        m: "m1",
        iat: T0,
        exp: T0 + 60_000,
        n: "n1",
        p: "pres-1",
      },
    });
  });

  test("varias activas → chooseMission ordenadas por nombre", () => {
    const missions = [
      {id: "b", data: {name: "Soyapango", status: "active", schedule: open}},
      {id: "a", data: {name: "Apopa", active: true, schedule: open}},
    ];
    assert.deepEqual(decideQrIssue(missions, null, ctx), {
      status: "chooseMission",
      missions: [{id: "a", name: "Apopa"}, {id: "b", name: "Soyapango"}],
    });
  });

  test("missionId elegido debe estar activo", () => {
    const missions = [
      {id: "b", data: {name: "Soyapango", status: "active", schedule: open}},
      {id: "a", data: {name: "Apopa", status: "active", schedule: open}},
      {id: "c", data: {name: "Off", status: "inactive", schedule: open}},
    ];
    const ok = decideQrIssue(missions, "b", ctx);
    assert.equal(ok.status, "ok");
    assert.equal(ok.status === "ok" && ok.missionId, "b");
    assert.deepEqual(decideQrIssue(missions, "c", ctx), {
      status: "noActiveMission",
    });
    assert.deepEqual(decideQrIssue(missions, "zzz", ctx), {
      status: "noActiveMission",
    });
  });
});
