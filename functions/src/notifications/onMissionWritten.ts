import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {describeError} from "../core/errors";
import {isMissionActive, missionName} from "../missions/schedule";
import {claimAnnouncement} from "./announce";
import {shouldAnnounceMission} from "./announceRules";
import {sendToTopic} from "./send";
import {TOPIC_MISSIONS} from "./topics";

export const onMissionWritten = onDocumentWritten(
  "stamp/{missionId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const before = event.data?.before;
    const beforeData = before?.exists ? before.data() : undefined;
    const data = after.data() ?? {};
    if (!shouldAnnounceMission(beforeData, data)) return;

    const missionId = event.params.missionId;
    try {
      const db = getFirestore();
      const claimed = await claimAnnouncement(db, after.ref, isMissionActive);
      if (!claimed) return;
      await sendToTopic(TOPIC_MISSIONS, {
        title: "Nueva misión",
        body: `Ya está disponible: ${missionName(data)}`,
        data: {type: "newMission", missionId},
      });
    } catch (error) {
      logger.error("No se pudo anunciar la misión", {
        missionId,
        error: describeError(error),
      });
    }
  },
);
