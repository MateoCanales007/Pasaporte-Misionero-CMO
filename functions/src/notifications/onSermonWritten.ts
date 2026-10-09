import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {describeError} from "../core/errors";
import {claimAnnouncement} from "./announce";
import {isSermonPublished, shouldAnnounceSermon} from "./announceRules";
import {sendToTopic} from "./send";
import {TOPIC_SERMONS} from "./topics";

export const onSermonWritten = onDocumentWritten(
  "sermons/{sermonId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data() ?? {};
    if (!shouldAnnounceSermon(data)) return;

    const sermonId = event.params.sermonId;
    try {
      const claimed = await claimAnnouncement(
        getFirestore(),
        after.ref,
        isSermonPublished,
      );
      if (!claimed) return;
      const title = typeof data.title === "string" && data.title.trim() ?
        data.title.trim() :
        "Escucha la nueva prédica";
      await sendToTopic(TOPIC_SERMONS, {
        title: "Nueva prédica",
        body: title,
        data: {type: "newSermon", sermonId},
      });
    } catch (error) {
      logger.error("No se pudo anunciar la prédica", {
        sermonId,
        error: describeError(error),
      });
    }
  },
);
