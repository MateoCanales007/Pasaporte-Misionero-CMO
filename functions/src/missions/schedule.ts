import {DEFAULT_MISSION_NAME} from "../constants";
import {ValidationError} from "../core/errors";
import {timestampToMillis} from "../core/time";
import {Data, isPlainObject} from "../core/validation";

export interface ScheduleWindow {
  startMs: number;
  endMs: number;
}

export type MissionStatus = "draft" | "active" | "inactive";

export interface MissionRecord {
  id: string;
  data: Data;
}

export interface ActiveMission {
  id: string;
  name: string;
  windows: ScheduleWindow[];
}

export const MAX_SCHEDULE_WINDOWS = 20;
const MIN_MS = Date.UTC(2000, 0, 1);
const MAX_MS = Date.UTC(2100, 0, 1);

/**
 * @param {unknown} value Valor a revisar.
 * @return {boolean} true si es un estado de misión válido.
 */
export function isMissionStatus(value: unknown): value is MissionStatus {
  return value === "draft" || value === "active" || value === "inactive";
}

/**
 * @param {unknown} value Milisegundos recibidos.
 * @return {boolean} true si es un instante finito y razonable.
 */
function isSaneMillis(value: unknown): value is number {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= MIN_MS &&
    value <= MAX_MS;
}

/**
 * Valida horarios recibidos del cliente ({start, end} en ms).
 * @param {unknown} input Lista recibida.
 * @param {object} options minWindows (por defecto 1).
 * @return {ScheduleWindow[]} Ventanas ordenadas por inicio.
 */
export function validateSchedules(
  input: unknown,
  options: {minWindows?: number} = {},
): ScheduleWindow[] {
  const minWindows = options.minWindows ?? 1;
  const field = "schedules";
  if (!Array.isArray(input)) {
    throw new ValidationError("Los horarios deben ser una lista.", field);
  }
  if (input.length < minWindows) {
    throw new ValidationError("Agrega al menos un horario.", field);
  }
  if (input.length > MAX_SCHEDULE_WINDOWS) {
    throw new ValidationError(
      `Máximo ${MAX_SCHEDULE_WINDOWS} horarios por misión.`,
      field,
    );
  }
  const windows = input.map((entry) => {
    if (!isPlainObject(entry) ||
      !isSaneMillis(entry.start) ||
      !isSaneMillis(entry.end)) {
      throw new ValidationError(
        "Cada horario debe tener un inicio y un fin válidos.",
        field,
      );
    }
    const window = {
      startMs: Math.trunc(entry.start),
      endMs: Math.trunc(entry.end),
    };
    if (window.startMs >= window.endMs) {
      throw new ValidationError(
        "El inicio de cada horario debe ser anterior a su fin.",
        field,
      );
    }
    return window;
  });
  windows.sort((a, b) => a.startMs - b.startMs);
  for (let i = 1; i < windows.length; i++) {
    if (windows[i].startMs < windows[i - 1].endMs) {
      throw new ValidationError("Los horarios no pueden solaparse.", field);
    }
  }
  return windows;
}

/**
 * Lee el campo schedule guardado ([{start: Timestamp, end: Timestamp}]);
 * descarta entradas corruptas.
 * @param {unknown} raw Valor almacenado.
 * @return {ScheduleWindow[]} Ventanas válidas ordenadas.
 */
export function parseStoredSchedule(raw: unknown): ScheduleWindow[] {
  if (!Array.isArray(raw)) return [];
  const windows: ScheduleWindow[] = [];
  for (const entry of raw) {
    if (!isPlainObject(entry)) continue;
    const startMs = timestampToMillis(entry.start);
    const endMs = timestampToMillis(entry.end);
    if (startMs === null || endMs === null || startMs >= endMs) continue;
    windows.push({startMs, endMs});
  }
  return windows.sort((a, b) => a.startMs - b.startMs);
}

/**
 * @param {ScheduleWindow[]} windows Ventanas.
 * @param {number} nowMs Instante a evaluar.
 * @return {boolean} true si start <= now < end en alguna ventana.
 */
export function isWithinAnyWindow(
  windows: ScheduleWindow[],
  nowMs: number,
): boolean {
  return windows.some((w) => w.startMs <= nowMs && nowMs < w.endMs);
}

/**
 * Activa = status "active"; documentos heredados sin status usan active.
 * @param {Data} data Documento de stamp/{id}.
 * @return {boolean} true si la misión está activa.
 */
export function isMissionActive(data: Data): boolean {
  if (data.status === undefined || data.status === null) {
    return data.active === true;
  }
  return data.status === "active";
}

/**
 * @param {Data} data Documento de stamp/{id}.
 * @return {MissionStatus | null} Estado efectivo (derivado si es heredado).
 */
export function missionStatusOf(data: Data): MissionStatus | null {
  if (isMissionStatus(data.status)) return data.status;
  if (data.status === undefined || data.status === null) {
    return data.active === true ? "active" : "inactive";
  }
  return null;
}

/**
 * @param {Data} data Documento de stamp/{id}.
 * @return {string} Nombre o "Misión".
 */
export function missionName(data: Data): string {
  const name = typeof data.name === "string" ? data.name.trim() : "";
  return name.length > 0 ? name : DEFAULT_MISSION_NAME;
}

/**
 * Misiones activas cuyo horario incluye nowMs, ordenadas por nombre.
 * @param {MissionRecord[]} missions Catálogo.
 * @param {number} nowMs Hora del servidor.
 * @return {ActiveMission[]} Misiones disponibles ahora.
 */
export function findActiveMissions(
  missions: MissionRecord[],
  nowMs: number,
): ActiveMission[] {
  const result: ActiveMission[] = [];
  for (const mission of missions) {
    if (!isMissionActive(mission.data)) continue;
    const windows = parseStoredSchedule(mission.data.schedule);
    if (!isWithinAnyWindow(windows, nowMs)) continue;
    result.push({id: mission.id, name: missionName(mission.data), windows});
  }
  return result.sort((a, b) => a.name.localeCompare(b.name, "es"));
}
