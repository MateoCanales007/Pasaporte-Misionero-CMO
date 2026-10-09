import assert from "node:assert/strict";
import {createHmac} from "node:crypto";
import {describe, test} from "node:test";
import {QR_REDEEM_GRACE_MS} from "../src/constants";
import {
  generateNonce,
  QrTokenPayload,
  signQrToken,
  verifyQrToken,
} from "../src/qr/token";
import {T0} from "./support/fakes";

const SECRET = "unit-test-secret-0123456789abcdef";
const payload: QrTokenPayload = {
  v: 1,
  m: "mission-1",
  iat: T0,
  exp: T0 + 60_000,
  n: "bm9uY2Utbm9uY2U",
  p: "presenter-uid",
};

/**
 * Firma un cuerpo arbitrario con el secreto de prueba.
 * @param {string} body Payload base64url.
 * @return {string} Token.
 */
function signRaw(body: string): string {
  const sig = createHmac("sha256", SECRET).update(`PMCMO1.${body}`)
    .digest("base64url");
  return `PMCMO1.${body}.${sig}`;
}

describe("signQrToken / verifyQrToken", () => {
  test("token válido tiene el formato del contrato y verifica", () => {
    const token = signQrToken(payload, SECRET);
    assert.match(token, /^PMCMO1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
    const body = JSON.parse(
      Buffer.from(token.split(".")[1], "base64url").toString("utf8"),
    );
    assert.deepEqual(body, payload);
    const result = verifyQrToken(token, SECRET, T0 + 1000);
    assert.deepEqual(result, {ok: true, payload});
  });

  test("payload alterado → badSignature", () => {
    const token = signQrToken(payload, SECRET);
    const [prefix, , sig] = token.split(".");
    const forged = Buffer.from(JSON.stringify({...payload, m: "otra"}))
      .toString("base64url");
    const result = verifyQrToken(`${prefix}.${forged}.${sig}`, SECRET, T0);
    assert.deepEqual(result, {ok: false, reason: "badSignature"});
  });

  test("firma alterada → badSignature", () => {
    const token = signQrToken(payload, SECRET);
    const last = token.at(-1) === "A" ? "B" : "A";
    const tampered = token.slice(0, -1) + last;
    assert.deepEqual(verifyQrToken(tampered, SECRET, T0), {
      ok: false,
      reason: "badSignature",
    });
    const truncated = token.slice(0, -4);
    assert.equal(
      (verifyQrToken(truncated, SECRET, T0) as {reason: string}).reason,
      "badSignature",
    );
  });

  test("secreto incorrecto → badSignature", () => {
    const token = signQrToken(payload, SECRET);
    assert.deepEqual(verifyQrToken(token, "otro-secreto-xxxxxxxx", T0), {
      ok: false,
      reason: "badSignature",
    });
  });

  test("formatos inválidos → malformed", () => {
    const good = signQrToken(payload, SECRET);
    const cases: unknown[] = [
      "",
      "abc",
      "PMCMO1.abc",
      "PMCMO1.a.b.c",
      good.replace("PMCMO1", "PMCMO2"),
      "PMCMO1.ab$cd.efgh",
      "PMCMO1..abc",
      123,
      null,
      undefined,
      {token: good},
      `PMCMO1.${"a".repeat(3000)}.abc`,
    ];
    for (const value of cases) {
      assert.deepEqual(
        verifyQrToken(value, SECRET, T0),
        {ok: false, reason: "malformed"},
        `caso: ${String(value).slice(0, 40)}`,
      );
    }
  });

  test("firma válida pero payload no JSON o con forma incorrecta", () => {
    const notJson = Buffer.from("no es json").toString("base64url");
    assert.deepEqual(verifyQrToken(signRaw(notJson), SECRET, T0), {
      ok: false,
      reason: "malformed",
    });
    const badShapes = [
      {...payload, v: 2},
      {...payload, m: "a/b"},
      {...payload, m: ""},
      {...payload, iat: "123"},
      {...payload, exp: payload.iat - 1},
      {...payload, n: ""},
      {...payload, p: 5},
      [payload],
    ];
    for (const shape of badShapes) {
      const body = Buffer.from(JSON.stringify(shape)).toString("base64url");
      assert.equal(
        (verifyQrToken(signRaw(body), SECRET, T0) as {reason: string}).reason,
        "malformed",
      );
    }
  });

  test("vencido después de exp + gracia", () => {
    const token = signQrToken(payload, SECRET);
    const now = payload.exp + QR_REDEEM_GRACE_MS + 1;
    assert.deepEqual(verifyQrToken(token, SECRET, now), {
      ok: false,
      reason: "expired",
    });
  });

  test("dentro de la gracia se acepta", () => {
    const token = signQrToken(payload, SECRET);
    assert.equal(verifyQrToken(token, SECRET, payload.exp + 5_000).ok, true);
    assert.equal(verifyQrToken(token, SECRET, payload.exp).ok, true);
  });

  test("exactamente en el límite exp + gracia se acepta", () => {
    const token = signQrToken(payload, SECRET);
    const boundary = payload.exp + QR_REDEEM_GRACE_MS;
    assert.equal(verifyQrToken(token, SECRET, boundary).ok, true);
    assert.equal(verifyQrToken(token, SECRET, boundary + 1).ok, false);
  });

  test("la gracia es configurable", () => {
    const token = signQrToken(payload, SECRET);
    assert.equal(verifyQrToken(token, SECRET, payload.exp + 1, 0).ok, false);
  });

  test("nonce: 16 bytes en base64url y distinto cada vez", () => {
    const a = generateNonce();
    const b = generateNonce();
    assert.match(a, /^[A-Za-z0-9_-]{22}$/);
    assert.equal(Buffer.from(a, "base64url").length, 16);
    assert.notEqual(a, b);
  });
});
