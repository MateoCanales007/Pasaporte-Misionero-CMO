import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {describeError} from "../core/errors";
import {Data} from "../core/validation";
import {syncTokensTopics, unsubscribeFromAllTopics} from "./send";

/**
 * @param {Data | undefined} data Documento fcm_tokens/{id}.
 * @param {string} docId Id del documento (= token según el contrato).
 * @return {string} Token FCM.
 */
function tokenOf(data: Data | undefined, docId: string): string {
  const token = data?.token;
  return typeof token === "string" && token.length > 0 &&
    token.length <= 4096 ? token : docId;
}

export const onFcmTokenWritten = onDocumentWritten(
  "user_passport/{uid}/fcm_tokens/{tokenId}",
  async (event) => {
    const {uid, tokenId} = event.params;
    const before = event.data?.before;
    const after = event.data?.after;
    try {
      if (!after?.exists) {
        await unsubscribeFromAllTopics([tokenOf(before?.data(), tokenId)]);
        return;
      }
      const token = tokenOf(after.data(), tokenId);
      const previous = before?.exists ?
        tokenOf(before.data(), tokenId) :
        null;
      if (previous && previous !== token) {
        await unsubscribeFromAllTopics([previous]);
      }
      const passport = await getFirestore()
        .collection("user_passport").doc(uid).get();
      await syncTokensTopics([token], passport.get("notificationPrefs"));
    } catch (error) {
      logger.error("Error al sincronizar token FCM", {
        uid,
        error: describeError(error),
      });
    }
  },
);
