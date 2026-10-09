import {Firestore, getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {QR_SIGNING_SECRET} from "../config";
import {requireRole} from "../core/auth";
import {readSecret, secureCallable} from "../core/callable";
import {readOptionalDocId, requireData} from "../core/validation";
import {decideQrIssue} from "./issueQrTokenCore";
import {generateNonce} from "./token";

/**
 * Defensa adicional: si el espejo user_passport.role ya no es qrPresenter
 * (rol retirado y token aún sin refrescar) se rechaza.
 * @param {Firestore} db Firestore.
 * @param {string} uid Presentador.
 */
async function assertPresenterStillAllowed(
  db: Firestore,
  uid: string,
): Promise<void> {
  const snap = await db.collection("user_passport").doc(uid).get();
  const mirrored = snap.get("role");
  if (
    typeof mirrored === "string" &&
    mirrored !== "qrPresenter" &&
    mirrored !== "admin"
  ) {
    throw new HttpsError(
      "permission-denied",
      "Tu permiso para mostrar el QR fue retirado.",
    );
  }
}

export const issueQrToken = secureCallable(async (request) => {
  const {uid, role} = requireRole(request, ["admin", "qrPresenter"]);
  const data = requireData(request.data);
  const missionId = readOptionalDocId(
    data,
    "missionId",
    "El identificador de la misión no es válido.",
  );
  const secret = readSecret(QR_SIGNING_SECRET, 16);
  const db = getFirestore();
  if (role === "qrPresenter") await assertPresenterStillAllowed(db, uid);

  const snap = await db.collection("stamp").get();
  const missions = snap.docs.map((d) => ({id: d.id, data: d.data()}));
  return decideQrIssue(missions, missionId, {
    nowMs: Date.now(),
    secret,
    presenterUid: uid,
    nonce: generateNonce(),
  });
}, [QR_SIGNING_SECRET]);
