import {ValidationError} from "../core/errors";
import {
  isFiniteNumber,
  isHttpsUrl,
  isPlainObject,
  readOptionalDocId,
  requireData,
} from "../core/validation";
import {
  isMissionStatus,
  MissionStatus,
  ScheduleWindow,
  validateSchedules,
} from "./schedule";

export interface MissionInput {
  missionId: string | null;
  name: string;
  isoCode: string;
  image: string;
  location: {lat: number; lng: number};
  placeId: string | null;
  schedules: ScheduleWindow[];
  status: MissionStatus;
}

export const PLACE_ID_PATTERN = /^[A-Za-z0-9_-]{1,512}$/;
const ISO_CODE_PATTERN = /^[A-Z]{2,6}$/;

/**
 * @param {unknown} value Estado recibido.
 * @return {MissionStatus} Estado validado.
 */
export function parseMissionStatus(value: unknown): MissionStatus {
  if (!isMissionStatus(value)) {
    throw new ValidationError("El estado de la misión no es válido.", "status");
  }
  return value;
}

/**
 * @param {unknown} value Ubicación recibida.
 * @return {object} {lat, lng} dentro de rango.
 */
function parseLocation(value: unknown): {lat: number; lng: number} {
  const message = "La ubicación no es válida.";
  if (!isPlainObject(value)) throw new ValidationError(message, "location");
  const {lat, lng} = value;
  if (
    !isFiniteNumber(lat) || lat < -90 || lat > 90 ||
    !isFiniteNumber(lng) || lng < -180 || lng > 180
  ) {
    throw new ValidationError(message, "location");
  }
  return {lat, lng};
}

/**
 * Valida la entrada de saveMission según el contrato.
 * @param {unknown} raw request.data
 * @return {MissionInput} Datos normalizados.
 */
export function parseMissionInput(raw: unknown): MissionInput {
  const data = requireData(raw);
  const missionId = readOptionalDocId(
    data,
    "missionId",
    "El identificador de la misión no es válido.",
  );

  const name = typeof data.name === "string" ? data.name.trim() : "";
  if (name.length < 2 || name.length > 80) {
    throw new ValidationError(
      "El nombre debe tener entre 2 y 80 caracteres.",
      "name",
    );
  }

  const isoCode = typeof data.isoCode === "string" ?
    data.isoCode.trim().toUpperCase() :
    "";
  if (!ISO_CODE_PATTERN.test(isoCode)) {
    throw new ValidationError(
      "El código debe tener de 2 a 6 letras (A-Z).",
      "isoCode",
    );
  }

  const rawImage = data.image ?? "";
  if (typeof rawImage !== "string") {
    throw new ValidationError("La imagen no es válida.", "image");
  }
  const image = rawImage.trim();
  if (image !== "" && !isHttpsUrl(image, 2048)) {
    throw new ValidationError(
      "La imagen debe ser una URL https válida o quedar vacía.",
      "image",
    );
  }

  const location = parseLocation(data.location);

  let placeId: string | null = null;
  if (data.placeId !== undefined && data.placeId !== null &&
    data.placeId !== "") {
    if (typeof data.placeId !== "string" ||
      !PLACE_ID_PATTERN.test(data.placeId)) {
      throw new ValidationError(
        "El identificador del lugar no es válido.",
        "placeId",
      );
    }
    placeId = data.placeId;
  }

  const status = parseMissionStatus(data.status);
  const schedules = validateSchedules(data.schedules ?? [], {
    minWindows: status === "active" ? 1 : 0,
  });

  return {
    missionId,
    name,
    isoCode,
    image,
    location,
    placeId,
    schedules,
    status,
  };
}
