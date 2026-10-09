import {createHash, timingSafeEqual} from "node:crypto";

/**
 * Compara dos strings en tiempo constante (también si difieren en longitud).
 * @param {string} a Primer valor.
 * @param {string} b Segundo valor.
 * @return {boolean} true si son iguales.
 */
export function safeEqualStrings(a: string, b: string): boolean {
  const da = createHash("sha256").update(a, "utf8").digest();
  const db = createHash("sha256").update(b, "utf8").digest();
  return timingSafeEqual(da, db) && a.length === b.length;
}
