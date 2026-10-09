import {ValidationError} from "./errors";

export type Data = Record<string, unknown>;

/**
 * @param {unknown} value Valor a revisar.
 * @return {boolean} true si es un objeto simple (no arreglo ni null).
 */
export function isPlainObject(value: unknown): value is Data {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * @param {unknown} value Valor a convertir.
 * @return {Data} El objeto o {} si no lo es.
 */
export function asRecord(value: unknown): Data {
  return isPlainObject(value) ? value : {};
}

/**
 * Datos de una callable; null/undefined se tratan como {}.
 * @param {unknown} data request.data
 * @return {Data} Objeto de entrada.
 */
export function requireData(data: unknown): Data {
  if (data === undefined || data === null) return {};
  if (!isPlainObject(data)) {
    throw new ValidationError("Solicitud inválida.", "data");
  }
  return data;
}

interface StringRule {
  min?: number;
  max: number;
  trim?: boolean;
  message: string;
}

/**
 * Lee un string obligatorio.
 * @param {Data} data Entrada.
 * @param {string} field Campo.
 * @param {StringRule} rule Reglas de longitud.
 * @return {string} Valor (recortado si rule.trim).
 */
export function readString(
  data: Data,
  field: string,
  rule: StringRule,
): string {
  const raw = data[field];
  if (typeof raw !== "string") throw new ValidationError(rule.message, field);
  const value = rule.trim ? raw.trim() : raw;
  if (value.length < (rule.min ?? 1) || value.length > rule.max) {
    throw new ValidationError(rule.message, field);
  }
  return value;
}

/**
 * Lee un string opcional; undefined, null o "" (tras recortar) dan null.
 * @param {Data} data Entrada.
 * @param {string} field Campo.
 * @param {StringRule} rule Reglas de longitud.
 * @return {string | null} Valor o null.
 */
export function readOptionalString(
  data: Data,
  field: string,
  rule: StringRule,
): string | null {
  const raw = data[field];
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== "string") throw new ValidationError(rule.message, field);
  const value = rule.trim ? raw.trim() : raw;
  if (value.length === 0) return null;
  if (value.length > rule.max) throw new ValidationError(rule.message, field);
  return value;
}

/**
 * Id de documento Firestore seguro (sin "/", no "." ni "..", no __x__).
 * @param {unknown} id Valor a revisar.
 * @return {boolean} true si es válido.
 */
export function isValidDocId(id: unknown): id is string {
  if (typeof id !== "string") return false;
  if (id.length === 0 || Buffer.byteLength(id, "utf8") > 1500) return false;
  if (id.includes("/") || id === "." || id === "..") return false;
  return !/^__.*__$/.test(id);
}

/**
 * Lee un id de documento obligatorio.
 * @param {Data} data Entrada.
 * @param {string} field Campo.
 * @param {string} message Mensaje de error.
 * @return {string} Id válido.
 */
export function readDocId(data: Data, field: string, message: string): string {
  const value = data[field];
  if (!isValidDocId(value)) throw new ValidationError(message, field);
  return value;
}

/**
 * Lee un id de documento opcional (undefined/null/"" → null).
 * @param {Data} data Entrada.
 * @param {string} field Campo.
 * @param {string} message Mensaje de error.
 * @return {string | null} Id válido o null.
 */
export function readOptionalDocId(
  data: Data,
  field: string,
  message: string,
): string | null {
  const value = data[field];
  if (value === undefined || value === null || value === "") return null;
  if (!isValidDocId(value)) throw new ValidationError(message, field);
  return value;
}

/**
 * URL https absoluta, sin credenciales y con host.
 * @param {string} value Texto a revisar.
 * @param {number} maxLength Longitud máxima.
 * @return {boolean} true si es válida.
 */
export function isHttpsUrl(value: string, maxLength = 2048): boolean {
  if (value.length === 0 || value.length > maxLength) return false;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return false;
  }
  return url.protocol === "https:" &&
    url.username === "" &&
    url.password === "" &&
    url.hostname.length > 0;
}

/**
 * @param {unknown} value Valor a revisar.
 * @return {boolean} true si es un número finito.
 */
export function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}
