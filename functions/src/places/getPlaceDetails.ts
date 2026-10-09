import {PLACES_API_KEY} from "../config";
import {requireRole} from "../core/auth";
import {secureCallable} from "../core/callable";
import {DomainError} from "../core/errors";
import {asRecord, isFiniteNumber, requireData} from "../core/validation";
import {placesJson} from "./placesClient";
import {parsePlaceId} from "./placesInput";

export const getPlaceDetails = secureCallable(async (request) => {
  requireRole(request, ["admin"]);
  const placeId = parsePlaceId(requireData(request.data));
  const body = await placesJson(
    "details/json",
    {place_id: placeId, fields: "geometry"},
    "Error al obtener detalles",
  );
  const location = asRecord(asRecord(asRecord(body.result).geometry).location);
  if (!isFiniteNumber(location.lat) || !isFiniteNumber(location.lng)) {
    throw new DomainError("not-found", "No se encontró el lugar.");
  }
  return {success: true, location: {lat: location.lat, lng: location.lng}};
}, [PLACES_API_KEY]);
