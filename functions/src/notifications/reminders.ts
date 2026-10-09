import {REMINDER_HORIZON_MS} from "../constants";
import {
  isMissionActive,
  MissionRecord,
  missionName,
  parseStoredSchedule,
} from "../missions/schedule";

export interface ReminderCandidate {
  missionId: string;
  missionName: string;
  startMs: number;
  key: string;
}

/**
 * Ventanas de misiones activas que inician en (now, now + horizonte].
 * @param {MissionRecord[]} missions Catálogo.
 * @param {number} nowMs Hora del servidor.
 * @param {number} horizonMs Horizonte (1 h por defecto).
 * @return {ReminderCandidate[]} Avisos a enviar (clave única por ventana).
 */
export function findUpcomingReminders(
  missions: MissionRecord[],
  nowMs: number,
  horizonMs: number = REMINDER_HORIZON_MS,
): ReminderCandidate[] {
  const result: ReminderCandidate[] = [];
  for (const mission of missions) {
    if (!isMissionActive(mission.data)) continue;
    for (const w of parseStoredSchedule(mission.data.schedule)) {
      if (w.startMs > nowMs && w.startMs <= nowMs + horizonMs) {
        result.push({
          missionId: mission.id,
          missionName: missionName(mission.data),
          startMs: w.startMs,
          key: `${mission.id}_${w.startMs}`,
        });
      }
    }
  }
  return result;
}
