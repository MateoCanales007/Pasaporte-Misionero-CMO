import {PLACES_API_KEY} from "../config";
import {requireAuth} from "../core/auth";
import {secureCallable} from "../core/callable";
import {requireData} from "../core/validation";
import {placesPhotoBase64} from "./placesClient";
import {parsePhotoReference} from "./placesInput";

export const getMissionPlacePhoto = secureCallable(async (request) => {
  requireAuth(request);
  const photoReference = parsePhotoReference(requireData(request.data));
  const imageBase64 = await placesPhotoBase64(
    photoReference,
    "Error al obtener la foto",
  );
  return {success: true, imageBase64};
}, [PLACES_API_KEY]);
