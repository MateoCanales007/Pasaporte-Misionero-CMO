import {isPlainObject} from "../core/validation";

export const TOPIC_MISSIONS = "missions";
export const TOPIC_MISSION_REMINDERS = "mission_reminders";
export const TOPIC_SERMONS = "sermons";

export const ALL_TOPICS: readonly string[] = [
  TOPIC_MISSIONS,
  TOPIC_MISSION_REMINDERS,
  TOPIC_SERMONS,
];

export const DEFAULT_NOTIFICATION_PREFS = {
  newMission: true,
  missionReminder: true,
  newSermon: true,
  stampConfirmed: true,
} as const;

/**
 * Temas a los que debe estar suscrito un dispositivo. Solo un false explícito
 * desactiva una preferencia; lo ausente vale true.
 * @param {unknown} prefs user_passport.notificationPrefs
 * @return {string[]} Temas deseados (orden de ALL_TOPICS).
 */
export function topicsForPrefs(prefs: unknown): string[] {
  const p = isPlainObject(prefs) ? prefs : {};
  const topics: string[] = [];
  if (p.newMission !== false) topics.push(TOPIC_MISSIONS);
  if (p.missionReminder !== false) topics.push(TOPIC_MISSION_REMINDERS);
  if (p.newSermon !== false) topics.push(TOPIC_SERMONS);
  return topics;
}

/**
 * @param {unknown} prefs Preferencias.
 * @return {object} Temas a suscribir y a desuscribir.
 */
export function topicActions(
  prefs: unknown,
): {subscribe: string[]; unsubscribe: string[]} {
  const subscribe = topicsForPrefs(prefs);
  return {
    subscribe,
    unsubscribe: ALL_TOPICS.filter((t) => !subscribe.includes(t)),
  };
}

/**
 * @param {string[]} a Temas.
 * @param {string[]} b Temas.
 * @return {boolean} true si contienen los mismos temas.
 */
export function sameTopics(a: string[], b: string[]): boolean {
  return a.length === b.length && a.every((t) => b.includes(t));
}
