import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {BUSINESS_TIME_ZONE} from "../constants";
import {describeError, errorCode} from "../core/errors";
import {findUpcomingReminders} from "./reminders";
import {sendToTopic} from "./send";
import {TOPIC_MISSION_REMINDERS} from "./topics";

const ALREADY_EXISTS = 6;

export const sendMissionReminders = onSchedule(
  {schedule: "every 15 minutes", timeZone: BUSINESS_TIME_ZONE},
  async () => {
    const db = getFirestore();
    const snap = await db.collection("stamp").get();
    const missions = snap.docs.map((d) => ({id: d.id, data: d.data()}));
    const reminders = findUpcomingReminders(missions, Date.now());

    for (const reminder of reminders) {
      // create() falla si ya existe: garantiza un solo aviso por ventana.
      try {
        await db.collection("notification_log").doc(reminder.key).create({
          type: "missionReminder",
          missionId: reminder.missionId,
          windowStart: Timestamp.fromMillis(reminder.startMs),
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        const code = errorCode(error);
        if (code === ALREADY_EXISTS || code === "already-exists") continue;
        logger.error("No se pudo registrar el recordatorio", {
          key: reminder.key,
          error: describeError(error),
        });
        continue;
      }
      try {
        await sendToTopic(TOPIC_MISSION_REMINDERS, {
          title: "Misión por comenzar",
          body: `${reminder.missionName} comienza pronto`,
          data: {type: "missionReminder", missionId: reminder.missionId},
        });
      } catch (error) {
        logger.error("No se pudo enviar el recordatorio", {
          key: reminder.key,
          error: describeError(error),
        });
      }
    }
  },
);
