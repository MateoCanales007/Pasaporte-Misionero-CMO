// Utilidades de prueba compartidas (sin Firebase).

/**
 * Timestamp falso compatible con el duck typing de core/time.
 * @param {number} ms Milisegundos.
 * @return {object} Objeto con toMillis().
 */
export function ts(ms: number): {toMillis(): number} {
  return {toMillis: () => ms};
}

export const T0 = Date.UTC(2026, 9, 6, 15, 0, 0); // 2026-10-06 09:00 SV
export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;

/**
 * Ventana guardada como en Firestore.
 * @param {number} startMs Inicio.
 * @param {number} endMs Fin.
 * @return {object} {start, end} con Timestamps falsos.
 */
export function storedWindow(startMs: number, endMs: number) {
  return {start: ts(startMs), end: ts(endMs)};
}
