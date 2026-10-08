import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {describeError} from "../core/errors";
import {Data, isValidDocId} from "../core/validation";
import {listUserTokens, syncTokensTopics} from "../notifications/send";
import {ALL_TOPICS, sameTopics, topicsForPrefs} from "../notifications/topics";
import {buildPublicProfile, samePublicProfile} from "./publicProfile";

/**
 * @param {Firestore} db Firestore.
 * @param {Data} userDoc Perfil privado.
 * @return {Promise<string | null>} Nombre de cell/{cellId} si existe.
 */
async function readCellDocName(
  db: Firestore,
  userDoc: Data,
): Promise<string | null> {
  if (userDoc.showCell === false) return null;
  const cellId = typeof userDoc.cellId === "string" ?
    userDoc.cellId.trim() :
    "";
  if (!isValidDocId(cellId)) return null;
  const snap = await db.collection("cell").doc(cellId).get();
  const name = snap.exists ? snap.get("name") : null;
  return typeof name === "string" && name.trim() ? name : null;
}

/**
 * Recalcula public_profiles/{uid}; escribe solo si cambió algo.
 * Nunca escribe en user_passport (evita bucles).
 * @param {Firestore} db Firestore.
 * @param {string} uid Usuario.
 * @param {Data} userDoc Perfil privado.
 */
export async function syncPublicProfile(
  db: Firestore,
  uid: string,
  userDoc: Data,
): Promise<void> {
  const profileRef = db.collection("public_profiles").doc(uid);
  const [redemptions, cellDocName, existing] = await Promise.all([
    db.collection("user_passport").doc(uid).collection("redemptions")
      .select().get(),
    readCellDocName(db, userDoc),
    profileRef.get(),
  ]);
  const profile = buildPublicProfile(
    uid,
    userDoc,
    redemptions.docs.map((d) => d.id),
    cellDocName,
  );
  if (existing.exists && samePublicProfile(profile, existing.data())) return;
  await profileRef.set({...profile, updatedAt: FieldValue.serverTimestamp()});
}

export const onUserPassportWritten = onDocumentWritten(
  "user_passport/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const db = getFirestore();
    const after = event.data?.after;
    const before = event.data?.before;

    if (!after?.exists) {
      await db.collection("public_profiles").doc(uid).delete();
      return;
    }
    const userDoc = after.data() ?? {};

    try {
      await syncPublicProfile(db, uid, userDoc);
    } catch (error) {
      logger.error("No se pudo sincronizar el perfil público", {
        uid,
        error: describeError(error),
      });
    }

    // Sin documento previo se asume la suscripción por defecto (todos).
    const beforeTopics = before?.exists ?
      topicsForPrefs(before.data()?.notificationPrefs) :
      [...ALL_TOPICS];
    const afterTopics = topicsForPrefs(userDoc.notificationPrefs);
    if (sameTopics(beforeTopics, afterTopics)) return;
    try {
      const tokens = await listUserTokens(db, uid);
      await syncTokensTopics(tokens, userDoc.notificationPrefs);
    } catch (error) {
      logger.error("No se pudieron actualizar los temas FCM", {
        uid,
        error: describeError(error),
      });
    }
  },
);
