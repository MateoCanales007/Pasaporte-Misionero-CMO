import {ValidationError} from "../core/errors";
import {Data, isFiniteNumber} from "../core/validation";
import {PLACE_ID_PATTERN} from "../missions/missionInput";

/**
 * @param {Data} data Entrada.
 * @return {string} Texto de búsqueda (1..120).
 */
export function parseQuery(data: Data): string {
  const query = typeof data.query === "string" ? data.query.trim() : "";
  if (query.length < 1 || query.length > 120) {
    throw new ValidationError("La búsqueda no es válida.", "query");
  }
  return query;
}

/**
 * @param {unknown} value Valor recibido.
 * @return {boolean} true si es un placeId válido.
 */
export function isPlaceId(value: unknown): value is string {
  return typeof value === "string" && PLACE_ID_PATTERN.test(value);
}

/**
 * @param {Data} data Entrada.
 * @return {string} placeId obligatorio.
 */
export function parsePlaceId(data: Data): string {
  if (!isPlaceId(data.placeId)) {
    throw new ValidationError("El lugar no es válido.", "placeId");
  }
  return data.placeId;
}

/**
 * @param {Data} data Entrada.
 * @return {string} photoReference (1..2000).
 */
export function parsePhotoReference(data: Data): string {
  const ref = data.photoReference;
  if (typeof ref !== "string" || ref.length < 1 || ref.length > 2000) {
    throw new ValidationError("La foto no es válida.", "photoReference");
  }
  return ref;
}

export type PhotoSource =
  | {kind: "place"; placeId: string}
  | {kind: "coords"; lat: number; lng: number}
  | {kind: "none"};

/**
 * placeId tiene prioridad; si falta se usan lat/lng.
 * @param {Data} data Entrada de getPhotoReferences.
 * @return {PhotoSource} Fuente de fotos.
 */
export function parsePhotoSource(data: Data): PhotoSource {
  const {placeId, lat, lng} = data;
  if (placeId !== undefined && placeId !== null && placeId !== "") {
    if (!isPlaceId(placeId)) {
      throw new ValidationError("El lugar no es válido.", "placeId");
    }
    return {kind: "place", placeId};
  }
  const missing = (v: unknown) => v === undefined || v === null;
  if (missing(lat) && missing(lng)) return {kind: "none"};
  if (
    !isFiniteNumber(lat) || lat < -90 || lat > 90 ||
    !isFiniteNumber(lng) || lng < -180 || lng > 180
  ) {
    throw new ValidationError("La ubicación no es válida.", "location");
  }
  return {kind: "coords", lat, lng};
}

export const MAX_REFERENCES = 20;

/**
 * Une grupos de referencias en orden, sin repetidas y con un máximo.
 * @param {Array<Array<string>>} groups Referencias del lugar y cercanas.
 * @param {number} max Máximo de referencias.
 * @return {string[]} Referencias únicas.
 */
export function mergeReferences(
  groups: string[][],
  max: number = MAX_REFERENCES,
): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const group of groups) {
    for (const reference of group) {
      if (seen.has(reference)) continue;
      seen.add(reference);
      result.push(reference);
      if (result.length >= max) return result;
    }
  }
  return result;
}
