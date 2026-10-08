import {createHmac, randomBytes, timingSafeEqual} from "node:crypto";
import {
  QR_REDEEM_GRACE_MS,
  QR_TOKEN_MAX_LENGTH,
  QR_TOKEN_PREFIX,
} from "../constants";
import {isPlainObject, isValidDocId} from "../core/validation";

export interface QrTokenPayload {
  v: 1;
  m: string;
  iat: number;
  exp: number;
  n: string;
  p: string;
}

export type QrVerifyFailure = "malformed" | "badSignature" | "expired";

export type QrVerifyResult =
  | {ok: true; payload: QrTokenPayload}
  | {ok: false; reason: QrVerifyFailure};

const B64URL = /^[A-Za-z0-9_-]+$/;

/**
 * @return {string} Nonce de 16 bytes aleatorios en base64url.
 */
export function generateNonce(): string {
  return randomBytes(16).toString("base64url");
}

/**
 * @param {string} signingInput "PMCMO1.<payload>".
 * @param {string} secret Secreto HMAC.
 * @return {Buffer} Firma HMAC-SHA256.
 */
function hmac(signingInput: string, secret: string): Buffer {
  return createHmac("sha256", secret).update(signingInput, "utf8").digest();
}

/**
 * Firma un token QR: PMCMO1.<payload base64url>.<firma base64url>.
 * @param {QrTokenPayload} payload Datos del token.
 * @param {string} secret QR_SIGNING_SECRET.
 * @return {string} Token firmado.
 */
export function signQrToken(payload: QrTokenPayload, secret: string): string {
  const body = Buffer.from(JSON.stringify(payload), "utf8")
    .toString("base64url");
  const signingInput = `${QR_TOKEN_PREFIX}.${body}`;
  return `${signingInput}.${hmac(signingInput, secret).toString("base64url")}`;
}

/**
 * @param {unknown} value Payload decodificado.
 * @return {boolean} true si tiene la forma del contrato.
 */
function isPayload(value: unknown): value is QrTokenPayload {
  if (!isPlainObject(value)) return false;
  const {v, m, iat, exp, n, p} = value;
  return v === 1 &&
    isValidDocId(m) &&
    Number.isSafeInteger(iat) &&
    Number.isSafeInteger(exp) &&
    (exp as number) >= (iat as number) &&
    typeof n === "string" && n.length > 0 && n.length <= 128 &&
    typeof p === "string" && p.length > 0 && p.length <= 128;
}

/**
 * Verifica formato, firma (tiempo constante) y vigencia (exp + gracia).
 * @param {unknown} token Texto leído del QR.
 * @param {string} secret QR_SIGNING_SECRET.
 * @param {number} nowMs Hora del servidor.
 * @param {number} graceMs Tolerancia tras exp.
 * @return {QrVerifyResult} Resultado.
 */
export function verifyQrToken(
  token: unknown,
  secret: string,
  nowMs: number,
  graceMs: number = QR_REDEEM_GRACE_MS,
): QrVerifyResult {
  if (typeof token !== "string" || token.length > QR_TOKEN_MAX_LENGTH) {
    return {ok: false, reason: "malformed"};
  }
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== QR_TOKEN_PREFIX) {
    return {ok: false, reason: "malformed"};
  }
  const [, body, signature] = parts;
  if (!B64URL.test(body) || !B64URL.test(signature)) {
    return {ok: false, reason: "malformed"};
  }

  const expected = hmac(`${QR_TOKEN_PREFIX}.${body}`, secret);
  const provided = Buffer.from(signature, "base64url");
  if (
    provided.length !== expected.length ||
    !timingSafeEqual(provided, expected) ||
    provided.toString("base64url") !== signature
  ) {
    return {ok: false, reason: "badSignature"};
  }

  let payload: unknown;
  try {
    payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
  } catch {
    return {ok: false, reason: "malformed"};
  }
  if (!isPayload(payload)) return {ok: false, reason: "malformed"};
  if (nowMs > payload.exp + graceMs) return {ok: false, reason: "expired"};
  return {ok: true, payload};
}
