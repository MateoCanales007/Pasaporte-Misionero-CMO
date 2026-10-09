import {getAuth, UserRecord} from "firebase-admin/auth";
import {DomainError, errorCode} from "./errors";

/**
 * @param {string} uid Usuario de Auth.
 * @return {Promise<UserRecord>} Usuario; not-found si no existe.
 */
export async function getAuthUserOrThrow(uid: string): Promise<UserRecord> {
  try {
    return await getAuth().getUser(uid);
  } catch (error) {
    const code = errorCode(error);
    if (code === "auth/user-not-found" || code === "auth/invalid-uid") {
      throw new DomainError("not-found", "Usuario no encontrado.");
    }
    throw error;
  }
}
