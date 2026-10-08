import * as logger from "firebase-functions/logger";
import {HttpsError} from "firebase-functions/v2/https";
import {PLACES_API_KEY} from "../config";
import {readSecret} from "../core/callable";
import {isPlainObject} from "../core/validation";

const BASE_URL = "https://maps.googleapis.com/maps/api/place";
const TIMEOUT_MS = 5000;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

type JsonEndpoint = "autocomplete/json" | "details/json" | "nearbysearch/json";

/**
 * Construye la URL con la llave (la URL nunca se registra en logs).
 * @param {string} endpoint Ruta de la API.
 * @param {object} params Parámetros.
 * @return {string} URL completa.
 */
function buildUrl(endpoint: string, params: Record<string, string>): string {
  const query = new URLSearchParams({
    ...params,
    key: readSecret(PLACES_API_KEY, 10),
  });
  return `${BASE_URL}/${endpoint}?${query.toString()}`;
}

/**
 * GET JSON a Places API; lanza HttpsError("internal", errorMessage) si falla.
 * @param {JsonEndpoint} endpoint Ruta.
 * @param {object} params Parámetros (sin la llave).
 * @param {string} errorMessage Mensaje para el cliente.
 * @return {Promise<object>} Respuesta con status OK o ZERO_RESULTS.
 */
export async function placesJson(
  endpoint: JsonEndpoint,
  params: Record<string, string>,
  errorMessage: string,
): Promise<Record<string, unknown>> {
  const url = buildUrl(endpoint, params);
  let body: unknown;
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
      logger.warn("Places API HTTP error", {endpoint, http: response.status});
      throw new HttpsError("internal", errorMessage);
    }
    body = await response.json();
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.warn("Places API no disponible", {
      endpoint,
      error: error instanceof Error ? error.name : "unknown",
    });
    throw new HttpsError("internal", errorMessage);
  }
  const status = isPlainObject(body) ? body.status : undefined;
  if (!isPlainObject(body) || (status !== "OK" && status !== "ZERO_RESULTS")) {
    logger.warn("Places API respondió con error", {endpoint, status});
    throw new HttpsError("internal", errorMessage);
  }
  return body;
}

/**
 * Descarga una foto de Places y la devuelve en base64.
 * @param {string} photoReference Referencia de la foto.
 * @param {string} errorMessage Mensaje para el cliente.
 * @return {Promise<string>} Imagen en base64.
 */
export async function placesPhotoBase64(
  photoReference: string,
  errorMessage: string,
): Promise<string> {
  const url = buildUrl("photo", {
    maxwidth: "1000",
    photo_reference: photoReference,
  });
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const type = response.headers.get("content-type") ?? "";
    if (!response.ok || !type.startsWith("image/")) {
      logger.warn("Places foto no disponible", {http: response.status});
      throw new HttpsError("internal", errorMessage);
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length === 0 || bytes.length > MAX_PHOTO_BYTES) {
      throw new HttpsError("internal", errorMessage);
    }
    return bytes.toString("base64");
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.warn("Places foto falló", {
      error: error instanceof Error ? error.name : "unknown",
    });
    throw new HttpsError("internal", errorMessage);
  }
}
