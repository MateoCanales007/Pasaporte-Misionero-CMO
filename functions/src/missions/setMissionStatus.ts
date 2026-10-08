import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {requireRole} from "../core/auth";
import {secureCallable} from "../core/callable";
import {DomainError} from "../core/errors";
import {readDocId, requireData} from "../core/validation";
import {parseMissionStatus} from "./missionInput";
import {missionStatusOf, parseStoredSchedule} from "./schedule";

export const setMissionStatus = secureCallable(async (request) => {
  const {uid} = requireRole(request, ["admin"]);
  const data = requireData(request.data);
  const missionId = readDocId(
    data,
    "missionId",
    "El identificador de la misión no es válido.",
  );
  const status = parseMissionStatus(data.status);
  const db = getFirestore();
  const ref = db.collection("stamp").doc(missionId);

  const previous = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) {
      throw new DomainError("not-found", "La misión no existe.");
    }
    const current = snap.data() ?? {};
    if (
      status === "active" &&
      parseStoredSchedule(current.schedule).length === 0
    ) {
      throw new DomainError(
        "failed-precondition",
        "Una misión activa necesita al menos un horario.",
      );
    }
    t.update(ref, {
      status,
      active: status === "active",
      updatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return missionStatusOf(current);
  });

  await writeAuditLog(db, {
    action: "mission_status_changed",
    actorUid: uid,
    details: {missionId, from: previous, to: status},
  });
  return {missionId, status};
});
