import {Firestore, WriteBatch} from "firebase-admin/firestore";

export const MAX_BATCH_OPS = 400;

export interface BatchWriter {
  add(write: (batch: WriteBatch) => void): Promise<void>;
  flush(): Promise<void>;
  committed(): number;
}

/**
 * Agrupa escrituras en lotes de hasta maxOps operaciones.
 * @param {Firestore} db Firestore.
 * @param {number} maxOps Operaciones por lote.
 * @return {BatchWriter} Escritor por lotes.
 */
export function createBatchWriter(
  db: Firestore,
  maxOps: number = MAX_BATCH_OPS,
): BatchWriter {
  let batch = db.batch();
  let pending = 0;
  let committed = 0;
  const flush = async () => {
    if (pending === 0) return;
    await batch.commit();
    committed += pending;
    batch = db.batch();
    pending = 0;
  };
  return {
    add: async (write) => {
      write(batch);
      pending++;
      if (pending >= maxOps) await flush();
    },
    flush,
    committed: () => committed,
  };
}
