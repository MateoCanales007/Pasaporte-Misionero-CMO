interface TimestampLike {
  toMillis(): number;
}

/**
 * Detecta un Timestamp de Firestore sin importar el SDK (duck typing).
 * @param {unknown} value Valor a revisar.
 * @return {boolean} true si expone toMillis().
 */
export function isTimestampLike(value: unknown): value is TimestampLike {
  return typeof value === "object" &&
    value !== null &&
    typeof (value as {toMillis?: unknown}).toMillis === "function";
}

/**
 * Convierte un Timestamp (o Date) a milisegundos; cualquier otro valor da
 * null. Nunca sustituye por la hora actual.
 * @param {unknown} value Valor almacenado.
 * @return {number | null} Milisegundos o null.
 */
export function timestampToMillis(value: unknown): number | null {
  if (isTimestampLike(value)) {
    const ms = value.toMillis();
    return Number.isFinite(ms) ? ms : null;
  }
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}
