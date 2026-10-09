import {
  DocumentReference,
  FieldValue,
  Firestore,
} from "firebase-admin/firestore";
import {Data} from "../core/validation";
import {isAnnounced} from "./announceRules";

/**
 * Reserva el anuncio marcando announcedAt en una transacción, de modo que
 * dos eventos casi simultáneos no envíen la notificación dos veces.
 * @param {Firestore} db Firestore.
 * @param {DocumentReference} ref Documento a anunciar.
 * @param {Function} isEligible Condición evaluada con datos frescos.
 * @return {Promise<boolean>} true si este evento debe enviar el aviso.
 */
export async function claimAnnouncement(
  db: Firestore,
  ref: DocumentReference,
  isEligible: (data: Data) => boolean,
): Promise<boolean> {
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) return false;
    const data = snap.data() ?? {};
    if (isAnnounced(data) || !isEligible(data)) return false;
    t.update(ref, {announcedAt: FieldValue.serverTimestamp()});
    return true;
  });
}
