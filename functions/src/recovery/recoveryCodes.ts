import {
  createHash,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";
import {timestampToMillis} from "../core/time";
import {Data} from "../core/validation";

export const RECOVERY_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const RECOVERY_CODE_LENGTH = 8;
export const RECOVERY_CODE_TTL_MS = 30 * 60 * 1000;
export const RECOVERY_MAX_ATTEMPTS = 5;
export const RECOVERY_EMAIL_DOMAIN = "cmo.com";

export type RecoveryCheck =
  | "ok"
  | "missing"
  | "expired"
  | "locked"
  | "mismatch";

/**
 * Código de 8 caracteres sin ambiguos (sin I, L, O, 0, 1).
 * @param {Function} pick Generador uniforme [0, max) (crypto.randomInt).
 * @return {string} Código.
 */
export function generateCode(
  pick: (max: number) => number = randomInt,
): string {
  let code = "";
  for (let i = 0; i < RECOVERY_CODE_LENGTH; i++) {
    code += RECOVERY_CODE_ALPHABET[pick(RECOVERY_CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * @return {string} Sal aleatoria de 16 bytes en hex.
 */
export function generateSalt(): string {
  return randomBytes(16).toString("hex");
}

/**
 * @param {string} code Código normalizado.
 * @param {string} salt Sal.
 * @return {string} SHA-256 hex de "sal:código".
 */
export function hashCode(code: string, salt: string): string {
  return createHash("sha256").update(`${salt}:${code}`, "utf8").digest("hex");
}

/**
 * Mayúsculas, sin espacios ni guiones.
 * @param {string} input Código escrito por el usuario.
 * @return {string} Código normalizado.
 */
export function normalizeCode(input: string): string {
  return input.toUpperCase().replace(/[\s-]+/g, "");
}

/**
 * Igual que la app: minúsculas y sin espacios.
 * @param {string} input Usuario escrito.
 * @return {string} Usuario normalizado.
 */
export function normalizeUsername(input: string): string {
  return input.toLowerCase().replace(/\s+/g, "");
}

/**
 * @param {string} username Usuario normalizado.
 * @return {string} Email interno de Firebase Auth.
 */
export function usernameToEmail(username: string): string {
  return `${username}@${RECOVERY_EMAIL_DOMAIN}`;
}

/**
 * @param {string} a Hash hex.
 * @param {string} b Hash hex.
 * @return {boolean} true si coinciden (tiempo constante).
 */
export function hashesEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a, "hex");
  const bb = Buffer.from(b, "hex");
  return ba.length === bb.length && ba.length > 0 && timingSafeEqual(ba, bb);
}

/**
 * Evalúa un intento contra recovery_codes/{uid}.
 * @param {Data | null} doc Documento guardado.
 * @param {string} code Código normalizado.
 * @param {number} nowMs Hora del servidor.
 * @return {RecoveryCheck} Resultado.
 */
export function checkRecoveryCode(
  doc: Data | null,
  code: string,
  nowMs: number,
): RecoveryCheck {
  if (!doc) return "missing";
  const attempts = typeof doc.attempts === "number" ? doc.attempts : 0;
  if (attempts >= RECOVERY_MAX_ATTEMPTS) return "locked";
  const expiresAt = timestampToMillis(doc.expiresAt);
  if (expiresAt === null || nowMs > expiresAt) return "expired";
  if (typeof doc.hash !== "string" || typeof doc.salt !== "string") {
    return "missing";
  }
  return hashesEqual(hashCode(code, doc.salt), doc.hash) ? "ok" : "mismatch";
}
