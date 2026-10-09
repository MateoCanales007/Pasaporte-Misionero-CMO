import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {
  checkRecoveryCode,
  generateCode,
  generateSalt,
  hashCode,
  hashesEqual,
  normalizeCode,
  normalizeUsername,
  RECOVERY_CODE_ALPHABET,
  usernameToEmail,
} from "../src/recovery/recoveryCodes";
import {T0, ts} from "./support/fakes";

describe("normalización", () => {
  test("usuario: minúsculas y sin espacios (igual que la app)", () => {
    assert.equal(normalizeUsername(" Juan Pérez "), "juanpérez");
    assert.equal(normalizeUsername("ANA\tMARIA\n"), "anamaria");
    assert.equal(usernameToEmail("juan"), "juan@cmo.com");
  });

  test("código: mayúsculas, sin espacios ni guiones", () => {
    assert.equal(normalizeCode("abcd-efgh"), "ABCDEFGH");
    assert.equal(normalizeCode(" ab cd - ef gh "), "ABCDEFGH");
  });
});

describe("hash", () => {
  test("determinista, depende de la sal y es SHA-256 hex", () => {
    const salt = "00112233445566778899aabbccddeeff";
    const a = hashCode("ABCDEFGH", salt);
    assert.equal(a, hashCode("ABCDEFGH", salt));
    assert.match(a, /^[0-9a-f]{64}$/);
    assert.notEqual(a, hashCode("ABCDEFGH", "otra-sal"));
    assert.notEqual(a, hashCode("ABCDEFGJ", salt));
    assert.equal(hashesEqual(a, a), true);
    assert.equal(hashesEqual(a, hashCode("X", salt)), false);
    assert.equal(hashesEqual(a, "abc"), false);
    assert.equal(hashesEqual("", ""), false);
  });

  test("sal de 16 bytes", () => {
    assert.match(generateSalt(), /^[0-9a-f]{32}$/);
    assert.notEqual(generateSalt(), generateSalt());
  });
});

describe("generateCode", () => {
  test("alfabeto sin caracteres ambiguos", () => {
    assert.equal(RECOVERY_CODE_ALPHABET.length, 31);
    for (const ch of "ILO01") {
      assert.ok(!RECOVERY_CODE_ALPHABET.includes(ch));
    }
  });

  test("8 caracteres del alfabeto", () => {
    for (let i = 0; i < 300; i++) {
      const code = generateCode();
      assert.equal(code.length, 8);
      for (const ch of code) assert.ok(RECOVERY_CODE_ALPHABET.includes(ch));
    }
  });

  test("usa el generador inyectado", () => {
    assert.equal(generateCode(() => 0), "AAAAAAAA");
    assert.equal(generateCode((max) => max - 1), "99999999");
  });
});

describe("checkRecoveryCode", () => {
  const salt = "salt";
  const doc = (overrides = {}) => ({
    hash: hashCode("ABCDEFGH", salt),
    salt,
    expiresAt: ts(T0 + 30 * 60_000),
    attempts: 0,
    ...overrides,
  });

  test("código correcto (sin importar mayúsculas/guiones)", () => {
    assert.equal(checkRecoveryCode(doc(), normalizeCode("abcd-efgh"), T0),
      "ok");
  });

  test("casos inválidos", () => {
    assert.equal(checkRecoveryCode(null, "ABCDEFGH", T0), "missing");
    assert.equal(checkRecoveryCode(doc(), "ABCDEFGX", T0), "mismatch");
    assert.equal(
      checkRecoveryCode(doc(), "ABCDEFGH", T0 + 30 * 60_000 + 1),
      "expired",
    );
    assert.equal(
      checkRecoveryCode(doc({expiresAt: "mañana"}), "ABCDEFGH", T0),
      "expired",
    );
    assert.equal(
      checkRecoveryCode(doc({attempts: 5}), "ABCDEFGH", T0),
      "locked",
    );
    assert.equal(
      checkRecoveryCode(doc({hash: 5}), "ABCDEFGH", T0),
      "missing",
    );
  });
});
