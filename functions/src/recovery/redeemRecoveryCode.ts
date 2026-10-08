import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {secureCallable} from "../core/callable";
import {errorCode, ValidationError} from "../core/errors";
import {requireData} from "../core/validation";
import {
  checkRecoveryCode,
  generateSalt,
  hashCode,
  normalizeCode,
  normalizeUsername,
  usernameToEmail,
} from "./recoveryCodes";

const INVALID = {status: "invalid"} as const;

/**
 * @param {unknown} value Valor recibido.
 * @param {string} field Campo.
 * @param {number} max Longitud máxima.
 * @return {string} El string.
 */
function requireStringField(value: unknown, field: string, max: number) {
  if (typeof value !== "string" || value.length > max) {
    throw new ValidationError("Solicitud inválida.", field);
  }
  return value;
}

/**
 * @param {string} email Email interno.
 * @return {Promise<string | null>} uid o null si no existe.
 */
async function findUidByEmail(email: string): Promise<string | null> {
  try {
    return (await getAuth().getUserByEmail(email)).uid;
  } catch (error) {
    const code = errorCode(error);
    if (typeof code === "string" && code.startsWith("auth/")) return null;
    throw error;
  }
}

// Pública (sin sesión): misma respuesta si el usuario no existe o el código
// es incorrecto.
export const redeemRecoveryCode = secureCallable(async (request) => {
  const data = requireData(request.data);
  const username = requireStringField(data.username, "username", 100);
  const rawCode = requireStringField(data.code, "code", 40);
  const newPassword = requireStringField(data.newPassword, "newPassword", 1024);
  if (newPassword.length < 6 || newPassword.length > 128) {
    return {status: "weakPassword"} as const;
  }

  const normalized = normalizeUsername(username);
  const code = normalizeCode(rawCode);
  const uid = normalized && code ?
    await findUidByEmail(usernameToEmail(normalized)) :
    null;
  if (!uid) {
    hashCode(code, generateSalt()); // iguala aproximadamente el tiempo
    return INVALID;
  }

  const db = getFirestore();
  const ref = db.collection("recovery_codes").doc(uid);
  const check = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const result = checkRecoveryCode(
      snap.exists ? snap.data() ?? null : null,
      code,
      Date.now(),
    );
    if (result === "mismatch") {
      t.update(ref, {
        attempts: FieldValue.increment(1),
        lastAttemptAt: FieldValue.serverTimestamp(),
      });
    } else if (result === "ok") {
      t.delete(ref); // un solo uso
    }
    return result;
  });
  if (check !== "ok") return INVALID;

  try {
    await getAuth().updateUser(uid, {password: newPassword});
  } catch (error) {
    const reason = errorCode(error);
    if (
      reason === "auth/invalid-password" ||
      reason === "auth/password-does-not-meet-requirements"
    ) {
      return {status: "weakPassword"} as const;
    }
    throw error;
  }
  await getAuth().revokeRefreshTokens(uid);
  await writeAuditLog(db, {
    action: "password_recovered",
    actorUid: uid,
    targetUid: uid,
  });
  return {status: "ok"} as const;
});
