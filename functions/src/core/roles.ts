import {isPlainObject} from "./validation";

export type Role = "admin" | "qrPresenter";
export type AssignableRole = "user" | "qrPresenter";

/**
 * Rol a partir de los custom claims; ausente o desconocido = usuario normal.
 * @param {unknown} claims Claims del token o del usuario de Auth.
 * @return {Role | null} Rol o null.
 */
export function roleFromClaims(claims: unknown): Role | null {
  if (!isPlainObject(claims)) return null;
  const role = claims.role;
  return role === "admin" || role === "qrPresenter" ? role : null;
}

/**
 * @param {unknown} value Valor a revisar.
 * @return {boolean} true si es un rol asignable desde la app.
 */
export function isAssignableRole(value: unknown): value is AssignableRole {
  return value === "user" || value === "qrPresenter";
}

/**
 * Nuevos claims conservando los existentes; "user" elimina el claim role.
 * @param {unknown} existing Claims actuales.
 * @param {AssignableRole} role Rol destino.
 * @return {object} Claims a guardar.
 */
export function claimsWithRole(
  existing: unknown,
  role: AssignableRole | Role,
): Record<string, unknown> {
  const claims: Record<string, unknown> = isPlainObject(existing) ?
    {...existing} :
    {};
  if (role === "user") {
    delete claims.role;
  } else {
    claims.role = role;
  }
  return claims;
}
