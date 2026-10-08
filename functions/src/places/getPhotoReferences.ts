import {PLACES_API_KEY} from "../config";
import {requireAuth} from "../core/auth";
import {secureCallable} from "../core/callable";
import {asRecord, isPlainObject, requireData} from "../core/validation";
import {placesJson} from "./placesClient";
import {mergeReferences, parsePhotoSource} from "./placesInput";

const NEARBY_RADIUS_METERS = "300";
const ERROR_MESSAGE = "Error al obtener referencias";

/**
 * @param {unknown} photos Lista "photos" de Places.
 * @return {string[]} photo_reference válidos.
 */
function referencesOf(photos: unknown): string[] {
  if (!Array.isArray(photos)) return [];
  return photos
    .filter(isPlainObject)
    .map((p) => p.photo_reference)
    .filter((r): r is string => typeof r === "string" && r.length > 0);
}

/**
 * Fotos de lugares alrededor de unas coordenadas.
 * @param {number} lat Latitud.
 * @param {number} lng Longitud.
 * @return {Promise<string[]>} Referencias.
 */
async function nearbyReferences(lat: number, lng: number): Promise<string[]> {
  const body = await placesJson(
    "nearbysearch/json",
    {location: `${lat},${lng}`, radius: NEARBY_RADIUS_METERS},
    ERROR_MESSAGE,
  );
  const results = Array.isArray(body.results) ? body.results : [];
  return results.flatMap((place) => referencesOf(asRecord(place).photos));
}

export const getPhotoReferences = secureCallable(async (request) => {
  requireAuth(request);
  const source = parsePhotoSource(requireData(request.data));
  const groups: string[][] = [];

  if (source.kind === "place") {
    const body = await placesJson(
      "details/json",
      {place_id: source.placeId, fields: "photos,geometry"},
      ERROR_MESSAGE,
    );
    const result = asRecord(body.result);
    groups.push(referencesOf(result.photos));
    const location = asRecord(asRecord(result.geometry).location);
    if (typeof location.lat === "number" && typeof location.lng === "number") {
      groups.push(await nearbyReferences(location.lat, location.lng));
    }
  } else if (source.kind === "coords") {
    groups.push(await nearbyReferences(source.lat, source.lng));
  }
  return {success: true, references: mergeReferences(groups)};
}, [PLACES_API_KEY]);
