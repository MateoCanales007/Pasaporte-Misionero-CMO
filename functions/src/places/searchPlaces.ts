import {PLACES_API_KEY} from "../config";
import {requireRole} from "../core/auth";
import {secureCallable} from "../core/callable";
import {isPlainObject, requireData} from "../core/validation";
import {placesJson} from "./placesClient";
import {parseQuery} from "./placesInput";

export const searchPlaces = secureCallable(async (request) => {
  requireRole(request, ["admin"]);
  const query = parseQuery(requireData(request.data));
  const body = await placesJson(
    "autocomplete/json",
    {input: query, language: "es"},
    "Error en autocomplete",
  );
  const raw = Array.isArray(body.predictions) ? body.predictions : [];
  const predictions = raw
    .filter(isPlainObject)
    .filter((p) =>
      typeof p.description === "string" && typeof p.place_id === "string")
    .map((p) => ({description: p.description, place_id: p.place_id}));
  return {success: true, predictions};
}, [PLACES_API_KEY]);
