import {FieldValue, Firestore} from "firebase-admin/firestore";

export interface AuditEntry {
  action: string;
  actorUid: string;
  targetUid?: string | null;
  details?: Record<string, unknown>;
}

/**
 * Registra una acción sensible en audit_logs (solo servidor).
 * @param {Firestore} db Instancia de Firestore.
 * @param {AuditEntry} entry Datos del registro.
 */
export async function writeAuditLog(
  db: Firestore,
  entry: AuditEntry,
): Promise<void> {
  await db.collection("audit_logs").add({
    action: entry.action,
    actorUid: entry.actorUid,
    targetUid: entry.targetUid ?? null,
    details: entry.details ?? {},
    createdAt: FieldValue.serverTimestamp(),
  });
}
