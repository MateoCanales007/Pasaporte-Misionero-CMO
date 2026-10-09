import {
  FieldValue,
  GeoPoint,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {requireRole} from "../core/auth";
import {secureCallable} from "../core/callable";
import {DomainError} from "../core/errors";
import {parseMissionInput} from "./missionInput";

export const saveMission = secureCallable(async (request) => {
  const {uid} = requireRole(request, ["admin"]);
  const input = parseMissionInput(request.data);
  const db = getFirestore();

  const fields = {
    name: input.name,
    isoCode: input.isoCode,
    image: input.image,
    location: new GeoPoint(input.location.lat, input.location.lng),
    schedule: input.schedules.map((w) => ({
      start: Timestamp.fromMillis(w.startMs),
      end: Timestamp.fromMillis(w.endMs),
    })),
    status: input.status,
    active: input.status === "active",
    updatedBy: uid,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (input.missionId === null) {
    const ref = db.collection("stamp").doc();
    await ref.create({
      ...fields,
      ...(input.placeId !== null ? {placeId: input.placeId} : {}),
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    await writeAuditLog(db, {
      action: "mission_created",
      actorUid: uid,
      details: {missionId: ref.id, name: input.name, status: input.status},
    });
    return {missionId: ref.id};
  }

  const missionId = input.missionId;
  const ref = db.collection("stamp").doc(missionId);
  await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) {
      throw new DomainError("not-found", "La misión no existe.");
    }
    // createdBy/createdAt/announcedAt no se tocan; placeId null = sin lugar.
    t.update(ref, {...fields, placeId: input.placeId});
  });
  await writeAuditLog(db, {
    action: "mission_updated",
    actorUid: uid,
    details: {missionId, name: input.name, status: input.status},
  });
  return {missionId};
});
