import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {requireAuth} from "../core/auth";
import {secureCallable} from "../core/callable";
import {readOptionalString, requireData} from "../core/validation";

export const requestAccountDeletion = secureCallable(async (request) => {
  const uid = requireAuth(request);
  const data = requireData(request.data);
  const reason = readOptionalString(data, "reason", {
    max: 500,
    trim: true,
    message: "El motivo no puede superar 500 caracteres.",
  });
  const db = getFirestore();
  const passportRef = db.collection("user_passport").doc(uid);

  await db.runTransaction(async (t) => {
    const passport = await t.get(passportRef);
    t.set(db.collection("deletion_requests").doc(uid), {
      uid,
      reason,
      status: "pending",
      requestedAt: FieldValue.serverTimestamp(),
    });
    // Sin perfil no se crea un documento parcial.
    if (passport.exists) {
      t.set(passportRef, {
        deletionRequestedAt: FieldValue.serverTimestamp(),
        communityVisible: false,
      }, {merge: true});
    }
  });
  await writeAuditLog(db, {
    action: "account_deletion_requested",
    actorUid: uid,
    targetUid: uid,
  });
  return {status: "ok"} as const;
});
