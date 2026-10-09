import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {requireRole} from "../core/auth";
import {getAuthUserOrThrow} from "../core/authUsers";
import {secureCallable} from "../core/callable";
import {readString, requireData} from "../core/validation";
import {
  generateCode,
  generateSalt,
  hashCode,
  RECOVERY_CODE_TTL_MS,
} from "./recoveryCodes";

export const createRecoveryCode = secureCallable(async (request) => {
  const {uid: actorUid} = requireRole(request, ["admin"]);
  const data = requireData(request.data);
  const uid = readString(data, "uid", {
    max: 128,
    message: "El usuario no es válido.",
  });
  await getAuthUserOrThrow(uid);

  const code = generateCode();
  const salt = generateSalt();
  const expiresAt = Date.now() + RECOVERY_CODE_TTL_MS;
  const db = getFirestore();
  // Reemplaza un código anterior del mismo usuario (solo vale el último).
  await db.collection("recovery_codes").doc(uid).set({
    hash: hashCode(code, salt),
    salt,
    expiresAt: Timestamp.fromMillis(expiresAt),
    attempts: 0,
    createdBy: actorUid,
    createdAt: FieldValue.serverTimestamp(),
  });
  await writeAuditLog(db, {
    action: "recovery_code_created",
    actorUid,
    targetUid: uid,
    details: {expiresAt},
  });
  return {code, expiresAt};
});
