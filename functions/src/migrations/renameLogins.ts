import {Auth} from "firebase-admin/auth";
import {Firestore} from "firebase-admin/firestore";
import {writeAuditLog} from "../core/audit";
import {isPlainObject} from "../core/validation";
import {RECOVERY_EMAIL_DOMAIN} from "../recovery/recoveryCodes";

/** Cuenta antigua (correo real) que pasa a usar nombre de usuario. */
export interface LoginRename {
  fromEmail: string;
  username: string;
}

const USERNAME = /^[a-z0-9._-]{3,30}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_RENAMES = 10;

/**
 * Valida la lista recibida (pura, sin Firebase).
 * @param {unknown} raw Valor de `renameLogins`.
 * @return {LoginRename[]} Cambios válidos, normalizados.
 */
export function parseLoginRenames(raw: unknown): LoginRename[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw) || raw.length > MAX_RENAMES) {
    throw new Error("renameLogins inválido");
  }
  const seen = new Set<string>();
  return raw.map((item) => {
    if (!isPlainObject(item)) throw new Error("renameLogins inválido");
    const fromEmail = String(item.fromEmail ?? "").trim().toLowerCase();
    const username = String(item.username ?? "").trim().toLowerCase();
    if (!EMAIL.test(fromEmail) ||
      fromEmail.endsWith(`@${RECOVERY_EMAIL_DOMAIN}`)) {
      throw new Error(`Correo de origen inválido: ${fromEmail}`);
    }
    if (!USERNAME.test(username) || seen.has(username)) {
      throw new Error(`Usuario inválido o repetido: ${username}`);
    }
    seen.add(username);
    return {fromEmail, username};
  });
}

export type RenameOutcome =
  | "renamed" | "wouldRename" | "alreadyDone" | "notFound" | "usernameTaken";

/**
 * Cambia el correo de acceso de cuentas antiguas a `usuario@cmo.com`.
 * Conserva uid, contraseña y datos. Idempotente y nunca borra nada.
 * @param {Firestore} db Firestore.
 * @param {Auth} auth Firebase Auth.
 * @param {LoginRename[]} renames Cambios a aplicar.
 * @param {boolean} dryRun true = solo reporta.
 * @return {Promise<object[]>} Resultado por cuenta.
 */
export async function applyLoginRenames(
  db: Firestore,
  auth: Auth,
  renames: LoginRename[],
  dryRun: boolean,
): Promise<{username: string; outcome: RenameOutcome}[]> {
  const results: {username: string; outcome: RenameOutcome}[] = [];
  for (const {fromEmail, username} of renames) {
    const toEmail = `${username}@${RECOVERY_EMAIL_DOMAIN}`;
    const source = await auth.getUserByEmail(fromEmail).catch(() => null);
    const target = await auth.getUserByEmail(toEmail).catch(() => null);
    if (!source) {
      results.push({username, outcome: target ? "alreadyDone" : "notFound"});
      continue;
    }
    if (target) {
      results.push({username, outcome: "usernameTaken"});
      continue;
    }
    if (dryRun) {
      results.push({username, outcome: "wouldRename"});
      continue;
    }
    await auth.updateUser(source.uid, {email: toEmail});
    const passport = db.collection("user_passport").doc(source.uid);
    if ((await passport.get()).exists) {
      await passport.set({username}, {merge: true});
    }
    await writeAuditLog(db, {
      action: "login_renamed",
      actorUid: "migration",
      targetUid: source.uid,
      details: {from: fromEmail, to: toEmail},
    });
    results.push({username, outcome: "renamed"});
  }
  return results;
}
