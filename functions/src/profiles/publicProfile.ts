import {
  DEFAULT_DISPLAY_NAME,
  DEFAULT_INITIALS,
  PUBLIC_PROFILE_MAX_STAMP_IDS,
} from "../constants";
import {Data} from "../core/validation";
import {summarizeLegacyStamps} from "../passport/legacyStamps";

export interface PublicProfile {
  uid: string;
  displayName: string;
  initials: string;
  cellName: string | null;
  nationality: string | null;
  stampCount: number;
  stampIds: string[];
  communityVisible: boolean;
}

/**
 * @param {unknown} value Valor.
 * @param {number} max Longitud máxima.
 * @return {string} Texto recortado ("" si no es string).
 */
function cleanText(value: unknown, max: number): string {
  if (typeof value !== "string") return "";
  return Array.from(value.trim().replace(/\s+/g, " ")).slice(0, max).join("");
}

/**
 * Ids de user_passport.stamps[] (formato heredado).
 * @param {Data} userDoc Perfil privado.
 * @return {string[]} Ids de misión únicos.
 */
export function legacyStampIds(userDoc: Data): string[] {
  return [...summarizeLegacyStamps(userDoc).stamps.keys()];
}

/**
 * Unión ordenada de canjes y sellos heredados.
 * @param {Data} userDoc Perfil privado.
 * @param {string[]} redemptionIds Ids de redemptions/.
 * @return {string[]} Ids únicos ordenados.
 */
export function unionStampIds(userDoc: Data, redemptionIds: string[]) {
  return [...new Set([...redemptionIds, ...legacyStampIds(userDoc)])].sort();
}

/**
 * @param {string} displayName Nombre visible.
 * @return {string} Iniciales de las dos primeras palabras o "CM".
 */
export function initialsFor(displayName: string): string {
  const words = displayName.split(" ").filter((w) => w.length > 0);
  const letters = words.slice(0, 2)
    .map((w) => Array.from(w)[0] ?? "")
    .join("")
    .toLocaleUpperCase("es");
  return letters.length > 0 ? letters : DEFAULT_INITIALS;
}

/**
 * Nombre de célula a publicar: nombre del documento cell/{id}, o el texto
 * libre si no es "otra"; null si showCell es false.
 * @param {Data} userDoc Perfil privado.
 * @param {string | null} cellDocName Nombre leído de cell/{cellId}.
 * @return {string | null} Célula visible.
 */
export function resolveCellName(
  userDoc: Data,
  cellDocName: string | null,
): string | null {
  if (userDoc.showCell === false) return null;
  const fromDoc = cleanText(cellDocName, 80);
  if (fromDoc) return fromDoc;
  const cellId = cleanText(userDoc.cellId, 80);
  if (cellId && cellId.toLowerCase() !== "otra") return cellId;
  return null;
}

/**
 * Perfil público: nunca incluye fecha de nacimiento, usuario ni número de
 * pasaporte; nacionalidad solo con showNationality === true.
 * @param {string} uid Usuario.
 * @param {Data} userDoc user_passport/{uid}.
 * @param {string[]} redemptionIds Ids de redemptions/.
 * @param {string | null} cellDocName Nombre de cell/{cellId} si existe.
 * @return {PublicProfile} Datos para public_profiles/{uid}.
 */
export function buildPublicProfile(
  uid: string,
  userDoc: Data,
  redemptionIds: string[],
  cellDocName: string | null,
): PublicProfile {
  const fullName = cleanText(userDoc.fullName, 80);
  const displayName = fullName || DEFAULT_DISPLAY_NAME;
  const nationality = userDoc.showNationality === true ?
    cleanText(userDoc.nationality, 60) || null :
    null;
  const allIds = unionStampIds(userDoc, redemptionIds);
  const deletionRequested = userDoc.deletionRequestedAt !== undefined &&
    userDoc.deletionRequestedAt !== null;
  return {
    uid,
    displayName,
    initials: fullName ? initialsFor(fullName) : DEFAULT_INITIALS,
    cellName: resolveCellName(userDoc, cellDocName),
    nationality,
    stampCount: allIds.length,
    stampIds: allIds.slice(0, PUBLIC_PROFILE_MAX_STAMP_IDS),
    communityVisible: userDoc.communityVisible !== false && !deletionRequested,
  };
}

/**
 * Compara el perfil calculado con el guardado (ignora updatedAt).
 * @param {PublicProfile} next Perfil calculado.
 * @param {Data | undefined} stored Documento existente.
 * @return {boolean} true si no hay cambios relevantes.
 */
export function samePublicProfile(
  next: PublicProfile,
  stored: Data | undefined,
): boolean {
  if (!stored) return false;
  const storedIds = Array.isArray(stored.stampIds) ? stored.stampIds : null;
  return stored.uid === next.uid &&
    stored.displayName === next.displayName &&
    stored.initials === next.initials &&
    (stored.cellName ?? null) === next.cellName &&
    (stored.nationality ?? null) === next.nationality &&
    stored.stampCount === next.stampCount &&
    stored.communityVisible === next.communityVisible &&
    storedIds !== null &&
    storedIds.length === next.stampIds.length &&
    storedIds.every((id, i) => id === next.stampIds[i]) &&
    Object.keys(stored).every((k) => k === "updatedAt" || k in next);
}
