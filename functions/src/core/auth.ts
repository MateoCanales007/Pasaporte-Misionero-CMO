import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {Role, roleFromClaims} from "./roles";

/**
 * Exige un usuario autenticado.
 * @param {CallableRequest} request Solicitud de la callable.
 * @return {string} uid del usuario.
 */
export function requireAuth(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

/**
 * Exige uno de los roles indicados (custom claim "role").
 * @param {CallableRequest} request Solicitud de la callable.
 * @param {Role[]} roles Roles permitidos.
 * @return {object} uid y rol del usuario.
 */
export function requireRole(
  request: CallableRequest<unknown>,
  roles: Role[],
): {uid: string; role: Role} {
  const uid = requireAuth(request);
  const role = roleFromClaims(request.auth?.token);
  if (!role || !roles.includes(role)) {
    throw new HttpsError(
      "permission-denied",
      "No tienes permisos para realizar esta acción.",
    );
  }
  return {uid, role};
}
