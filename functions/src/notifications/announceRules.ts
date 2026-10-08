import {Data} from "../core/validation";
import {isMissionActive} from "../missions/schedule";

/**
 * @param {Data} data Documento.
 * @return {boolean} true si ya tiene announcedAt.
 */
export function isAnnounced(data: Data): boolean {
  return data.announcedAt !== undefined && data.announcedAt !== null;
}

/**
 * Se anuncia solo al pasar a activa por primera vez. Si ya estaba activa
 * (p. ej. la migración agrega status a una misión heredada) no se anuncia.
 * @param {Data | undefined} before Datos previos.
 * @param {Data} after Datos nuevos.
 * @return {boolean} true si corresponde anunciar.
 */
export function shouldAnnounceMission(
  before: Data | undefined,
  after: Data,
): boolean {
  if (isAnnounced(after) || !isMissionActive(after)) return false;
  return !(before && isMissionActive(before));
}

/**
 * @param {Data} data Documento sermons/{id}.
 * @return {boolean} true si está publicada y no borrada.
 */
export function isSermonPublished(data: Data): boolean {
  return data.active === true && data.deleted !== true;
}

/**
 * @param {Data} data Documento sermons/{id}.
 * @return {boolean} true si corresponde anunciarla.
 */
export function shouldAnnounceSermon(data: Data): boolean {
  return !isAnnounced(data) && isSermonPublished(data);
}
