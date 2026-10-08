import {timestampToMillis} from "../core/time";
import {Data, isPlainObject, isValidDocId} from "../core/validation";

export interface LegacyStamp {
  missionId: string;
  /** Entradas en stamps[] con este stampId (puede haber duplicados). */
  entries: number;
  /** Fecha más antigua válida (Timestamp); null si ninguna lo es. */
  redeemedAtMs: number | null;
}

export interface LegacyStampsSummary {
  stamps: Map<string, LegacyStamp>;
  validEntries: number;
  invalidEntries: number;
}

/**
 * Agrupa user_passport.stamps[] por misión. Solo un Timestamp cuenta como
 * fecha; strings u otros valores dan null (nunca la hora actual).
 * @param {Data} passport Perfil privado.
 * @return {LegacyStampsSummary} Resumen.
 */
export function summarizeLegacyStamps(passport: Data): LegacyStampsSummary {
  const stamps = new Map<string, LegacyStamp>();
  let validEntries = 0;
  let invalidEntries = 0;
  const raw = Array.isArray(passport.stamps) ? passport.stamps : [];
  for (const entry of raw) {
    if (!isPlainObject(entry) || !isValidDocId(entry.stampId)) {
      invalidEntries++;
      continue;
    }
    validEntries++;
    const ms = timestampToMillis(entry.dateObtained);
    const current = stamps.get(entry.stampId);
    if (!current) {
      stamps.set(entry.stampId, {
        missionId: entry.stampId,
        entries: 1,
        redeemedAtMs: ms,
      });
      continue;
    }
    current.entries++;
    if (ms !== null &&
      (current.redeemedAtMs === null || ms < current.redeemedAtMs)) {
      current.redeemedAtMs = ms;
    }
  }
  return {stamps, validEntries, invalidEntries};
}
