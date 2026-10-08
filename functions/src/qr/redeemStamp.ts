import {
  DocumentReference,
  FieldValue,
  Firestore,
  getFirestore,
  Transaction,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {QR_SIGNING_SECRET, QR_TOKEN_MAX_LENGTH} from "../config";
import {requireAuth} from "../core/auth";
import {readSecret, secureCallable} from "../core/callable";
import {describeError, ValidationError} from "../core/errors";
import {readOptionalString, requireData} from "../core/validation";
import {sendToUserTokens} from "../notifications/send";
import {redemptionDoc} from "../passport/redemptionDocs";
import {
  RedeemRepository,
  RedeemTransaction,
  redeemStampCore,
} from "./redeemStampCore";

/**
 * Adaptador de la transacción de Firestore para la lógica de canje.
 * @param {Firestore} db Firestore.
 * @param {Transaction} t Transacción.
 * @return {RedeemTransaction} Operaciones del canje.
 */
function firestoreRedeemTx(db: Firestore, t: Transaction): RedeemTransaction {
  const passports = db.collection("user_passport");
  const read = async (ref: DocumentReference) => {
    const snap = await t.get(ref);
    return snap.exists ? snap.data() ?? {} : null;
  };
  return {
    getMission: (missionId) => read(db.collection("stamp").doc(missionId)),
    getUserPassport: (uid) => read(passports.doc(uid)),
    getRedemption: (uid, missionId) =>
      read(passports.doc(uid).collection("redemptions").doc(missionId)),
    createRedemption: (intent) => {
      const ref = passports.doc(intent.userId)
        .collection("redemptions").doc(intent.missionId);
      t.create(ref, redemptionDoc(intent));
    },
    recordStampConfirmed: (uid) => {
      t.update(passports.doc(uid), {
        stampCount: FieldValue.increment(1),
        lastRedemptionAt: FieldValue.serverTimestamp(),
      });
    },
  };
}

/**
 * @param {Firestore} db Firestore.
 * @return {RedeemRepository} Repositorio transaccional.
 */
export function firestoreRedeemRepository(db: Firestore): RedeemRepository {
  return {
    runTransaction: (fn) =>
      db.runTransaction((t) => fn(firestoreRedeemTx(db, t))),
  };
}

export const redeemStamp = secureCallable(async (request) => {
  const uid = requireAuth(request);
  const data = requireData(request.data);
  const token = data.token;
  if (typeof token !== "string" || token.length > QR_TOKEN_MAX_LENGTH) {
    throw new ValidationError("El código QR no es válido.", "token");
  }
  const rule = {max: 40, trim: true, message: "Dato de la app inválido."};
  const appVersion = readOptionalString(data, "appVersion", rule);
  const platform = readOptionalString(data, "platform", rule);
  const secret = readSecret(QR_SIGNING_SECRET, 16);
  const db = getFirestore();

  const outcome = await redeemStampCore(
    {repo: firestoreRedeemRepository(db), now: () => Date.now(), secret},
    {uid, token: token.trim(), appVersion, platform},
  );

  const result = outcome.result;
  if (outcome.notifyStampConfirmed && result.status === "confirmed") {
    try {
      await sendToUserTokens(db, uid, {
        title: "¡Sello confirmado!",
        body: `Tu sello de ${result.missionName} ya está en tu pasaporte.`,
        data: {type: "stampConfirmed", missionId: result.missionId},
      });
    } catch (error) {
      logger.warn("No se pudo notificar el sello", describeError(error));
    }
  }
  return result;
}, [QR_SIGNING_SECRET]);
