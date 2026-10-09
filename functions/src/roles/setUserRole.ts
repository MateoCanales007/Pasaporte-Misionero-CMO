import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {requireRole} from "../core/auth";
import {getAuthUserOrThrow} from "../core/authUsers";
import {secureCallable} from "../core/callable";
import {DomainError, ValidationError} from "../core/errors";
import {claimsWithRole, isAssignableRole, roleFromClaims} from "../core/roles";
import {readString, requireData} from "../core/validation";

export const setUserRole = secureCallable(async (request) => {
  const {uid: actorUid} = requireRole(request, ["admin"]);
  const data = requireData(request.data);
  const uid = readString(data, "uid", {
    max: 128,
    message: "El usuario no es válido.",
  });
  const role = data.role;
  if (!isAssignableRole(role)) {
    throw new ValidationError("El rol no es válido.", "role");
  }
  if (uid === actorUid) {
    throw new DomainError(
      "failed-precondition",
      "No puedes cambiar tu propio rol.",
    );
  }

  const target = await getAuthUserOrThrow(uid);
  const currentRole = roleFromClaims(target.customClaims);
  if (currentRole === "admin") {
    throw new DomainError(
      "permission-denied",
      "No se puede modificar a un administrador desde la app",
    );
  }

  await getAuth().setCustomUserClaims(
    uid,
    claimsWithRole(target.customClaims, role),
  );

  // Solo se refleja si el perfil existe: crear un documento parcial haría
  // creer a la app que el perfil está completo.
  const db = getFirestore();
  const passportRef = db.collection("user_passport").doc(uid);
  await db.runTransaction(async (t) => {
    const snap = await t.get(passportRef);
    if (!snap.exists) return;
    t.set(
      passportRef,
      {role, roleVersion: FieldValue.increment(1)},
      {merge: true},
    );
  });
  await writeAuditLog(db, {
    action: "role_changed",
    actorUid,
    targetUid: uid,
    details: {from: currentRole ?? "user", to: role},
  });
  return {uid, role};
});
