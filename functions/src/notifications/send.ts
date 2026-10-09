import {Firestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {describeError} from "../core/errors";
import {ALL_TOPICS, topicActions} from "./topics";

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

const MULTICAST_LIMIT = 500;
const TOPIC_BATCH_LIMIT = 1000;

/**
 * En el emulador no se contacta FCM real (evita notificar a usuarios reales).
 * @return {boolean} true si corre en el emulador de Functions.
 */
export function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

/**
 * @param {Array} items Elementos.
 * @param {number} size Tamaño de cada grupo.
 * @return {Array} Grupos.
 */
function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * Envía una notificación a un tema FCM.
 * @param {string} topic Tema.
 * @param {PushMessage} message Contenido.
 */
export async function sendToTopic(
  topic: string,
  message: PushMessage,
): Promise<void> {
  if (isEmulator()) {
    logger.info("[emulador] Notificación a tema omitida", {topic, message});
    return;
  }
  await getMessaging().send({
    topic,
    notification: {title: message.title, body: message.body},
    data: message.data ?? {},
    android: {priority: "high"},
    apns: {payload: {aps: {sound: "default"}}},
  });
}

/**
 * Tokens registrados en user_passport/{uid}/fcm_tokens.
 * @param {Firestore} db Firestore.
 * @param {string} uid Usuario.
 * @return {Promise<string[]>} Tokens.
 */
export async function listUserTokens(
  db: Firestore,
  uid: string,
): Promise<string[]> {
  const snap = await db.collection("user_passport").doc(uid)
    .collection("fcm_tokens").get();
  const tokens = new Set<string>();
  for (const doc of snap.docs) {
    const token = doc.get("token");
    tokens.add(typeof token === "string" && token.length > 0 ? token : doc.id);
  }
  return [...tokens];
}

/**
 * Envía una notificación a todos los dispositivos de un usuario.
 * @param {Firestore} db Firestore.
 * @param {string} uid Usuario.
 * @param {PushMessage} message Contenido.
 */
export async function sendToUserTokens(
  db: Firestore,
  uid: string,
  message: PushMessage,
): Promise<void> {
  const tokens = await listUserTokens(db, uid);
  if (tokens.length === 0) return;
  if (isEmulator()) {
    logger.info("[emulador] Notificación a usuario omitida", {uid, message});
    return;
  }
  for (const group of chunk(tokens, MULTICAST_LIMIT)) {
    const response = await getMessaging().sendEachForMulticast({
      tokens: group,
      notification: {title: message.title, body: message.body},
      data: message.data ?? {},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
    if (response.failureCount > 0) {
      logger.warn("Algunos envíos FCM fallaron", {
        uid,
        failures: response.failureCount,
      });
    }
  }
}

/**
 * @param {string[]} tokens Tokens.
 * @param {string} topic Tema.
 * @param {boolean} subscribe true suscribe, false desuscribe.
 */
async function updateTopic(
  tokens: string[],
  topic: string,
  subscribe: boolean,
): Promise<void> {
  for (const group of chunk(tokens, TOPIC_BATCH_LIMIT)) {
    try {
      const response = subscribe ?
        await getMessaging().subscribeToTopic(group, topic) :
        await getMessaging().unsubscribeFromTopic(group, topic);
      if (response.failureCount > 0) {
        logger.warn("Fallos al actualizar tema", {
          topic,
          subscribe,
          failures: response.failureCount,
        });
      }
    } catch (error) {
      logger.error("Error al actualizar tema", {
        topic,
        subscribe,
        error: describeError(error),
      });
    }
  }
}

/**
 * Suscribe los tokens a los temas según preferencias y los quita del resto.
 * @param {string[]} tokens Tokens del usuario.
 * @param {unknown} prefs notificationPrefs.
 */
export async function syncTokensTopics(
  tokens: string[],
  prefs: unknown,
): Promise<void> {
  if (tokens.length === 0) return;
  const {subscribe, unsubscribe} = topicActions(prefs);
  if (isEmulator()) {
    logger.info("[emulador] Sincronización de temas omitida", {
      tokens: tokens.length,
      subscribe,
      unsubscribe,
    });
    return;
  }
  for (const topic of subscribe) await updateTopic(tokens, topic, true);
  for (const topic of unsubscribe) await updateTopic(tokens, topic, false);
}

/**
 * Quita los tokens de todos los temas.
 * @param {string[]} tokens Tokens.
 */
export async function unsubscribeFromAllTopics(
  tokens: string[],
): Promise<void> {
  if (tokens.length === 0) return;
  if (isEmulator()) {
    logger.info("[emulador] Desuscripción omitida", {tokens: tokens.length});
    return;
  }
  for (const topic of ALL_TOPICS) await updateTopic(tokens, topic, false);
}
