import {randomBytes} from "node:crypto";
import {Auth, getAuth} from "firebase-admin/auth";
import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {MIGRATION_TOKEN} from "../config";
import {safeEqualStrings} from "../core/crypto";
import {describeError} from "../core/errors";
import {isPlainObject} from "../core/validation";
import {legacyRedemptionDoc} from "../passport/redemptionDocs";
import {createBatchWriter} from "./batchWriter";
import {applyLoginRenames, parseLoginRenames} from "./renameLogins";
import {
  MigrationPlan,
  planMigration,
  plannedWriteCount,
  PlannerMission,
  PlannerUser,
} from "./plan";

const AUTH_BATCH = 100;

/**
 * Lee perfiles, canjes, claims y catálogo.
 * @param {Firestore} db Firestore.
 * @param {Auth} auth Firebase Auth.
 * @return {Promise<object>} Entrada del planificador.
 */
async function loadInput(
  db: Firestore,
  auth: Auth,
): Promise<{users: PlannerUser[]; missions: PlannerMission[]}> {
  const [passports, stamps, redemptions] = await Promise.all([
    db.collection("user_passport").get(),
    db.collection("stamp").get(),
    db.collectionGroup("redemptions").select().get(),
  ]);

  const redemptionIds = new Map<string, string[]>();
  for (const doc of redemptions.docs) {
    const owner = doc.ref.parent.parent;
    if (!owner || owner.parent.id !== "user_passport") continue;
    const list = redemptionIds.get(owner.id) ?? [];
    list.push(doc.id);
    redemptionIds.set(owner.id, list);
  }

  const claims = new Map<string, Record<string, unknown>>();
  const uids = passports.docs.map((d) => d.id)
    .filter((uid) => uid.length <= 128);
  for (let i = 0; i < uids.length; i += AUTH_BATCH) {
    const group = uids.slice(i, i + AUTH_BATCH).map((uid) => ({uid}));
    const result = await auth.getUsers(group);
    for (const user of result.users) {
      claims.set(user.uid, user.customClaims ?? {});
    }
  }

  return {
    users: passports.docs.map((doc) => {
      const userClaims = claims.get(doc.id);
      return {
        uid: doc.id,
        data: doc.data(),
        redemptionIds: redemptionIds.get(doc.id) ?? [],
        authUser: userClaims ? {claims: userClaims} : null,
      };
    }),
    missions: stamps.docs.map((d) => ({id: d.id, data: d.data()})),
  };
}

/**
 * Aplica el plan: primero claims, luego documentos en lotes.
 * @param {Firestore} db Firestore.
 * @param {Auth} auth Firebase Auth.
 * @param {MigrationPlan} plan Plan calculado.
 */
async function applyPlan(
  db: Firestore,
  auth: Auth,
  plan: MigrationPlan,
): Promise<void> {
  for (const update of plan.claimUpdates) {
    await auth.setCustomUserClaims(update.uid, update.claims);
  }
  const passports = db.collection("user_passport");
  const writer = createBatchWriter(db);
  for (const intent of plan.redemptionCreates) {
    const ref = passports.doc(intent.userId)
      .collection("redemptions").doc(intent.missionId);
    await writer.add((b) => b.create(ref, legacyRedemptionDoc(intent)));
  }
  for (const patch of plan.passportPatches) {
    const fields = patch.incrementRoleVersion ?
      {...patch.set, roleVersion: FieldValue.increment(1)} :
      patch.set;
    await writer.add((b) =>
      b.set(passports.doc(patch.uid), fields, {merge: true}));
  }
  for (const update of plan.missionStatusUpdates) {
    const ref = db.collection("stamp").doc(update.missionId);
    await writer.add((b) => b.update(ref, {status: update.status}));
  }
  await writer.flush();
}

/**
 * Ejecuta la migración (dryRun por defecto) y devuelve el reporte.
 * @param {Firestore} db Firestore.
 * @param {Auth} auth Firebase Auth.
 * @param {boolean} dryRun true = solo reporta.
 * @return {Promise<object>} Reporte.
 */
export async function runMigration(
  db: Firestore,
  auth: Auth,
  dryRun: boolean,
): Promise<Record<string, unknown>> {
  const input = await loadInput(db, auth);
  const plan = planMigration(input.users, input.missions);
  const s = plan.stats;
  const base = {
    dryRun,
    users: s.users,
    usersWithLegacyStamps: s.usersWithLegacyStamps,
    legacyEntries: s.legacyEntries,
    invalidLegacyEntries: s.invalidLegacyEntries,
    redemptionsExisting: s.redemptionsExisting,
    unknownMissionRefs: s.unknownMissionRefs,
    corruptedDates: s.corruptedDates,
    authUsersMissing: s.authUsersMissing,
    roleMirrorsSet: s.roleMirrorsToSet,
    userDefaultsUpdated: s.userDefaultsUpdated,
    missionsStatusSet: s.missionsStatusSet,
  };

  if (dryRun) {
    return {
      ...base,
      redemptionsToCreate: s.redemptionsToCreate,
      claimsToSet: s.claimsToSet,
      verification: {
        allLegacyEntriesHaveRedemption: s.redemptionsToCreate === 0,
        pendingWrites: plannedWriteCount(plan),
      },
    };
  }

  const runId = `${new Date().toISOString().replace(/[:.]/g, "-")}_` +
    randomBytes(3).toString("hex");
  await applyPlan(db, auth, plan);

  // Verificación real: se vuelve a leer y a planificar; debe quedar en cero.
  const after = await loadInput(db, auth);
  const replan = planMigration(after.users, after.missions);
  const report = {
    ...base,
    runId,
    redemptionsCreated: s.redemptionsToCreate,
    claimsSet: s.claimsToSet,
    verification: {
      allLegacyEntriesHaveRedemption: replan.stats.redemptionsToCreate === 0,
      pendingWrites: plannedWriteCount(replan),
    },
  };
  await db.collection("_migrations").doc(runId).set({
    ...report,
    createdAt: FieldValue.serverTimestamp(),
  });
  return report;
}

/**
 * @param {unknown} token Token recibido.
 * @return {boolean} true si coincide con MIGRATION_TOKEN.
 */
function isAuthorized(token: unknown): boolean {
  let secret = "";
  try {
    secret = MIGRATION_TOKEN.value() ?? "";
  } catch {
    secret = "";
  }
  if (secret.length < 16) {
    logger.error("MIGRATION_TOKEN no está configurado.");
    return false;
  }
  return typeof token === "string" && safeEqualStrings(token, secret);
}

// Callable (no HTTP público): se despliega sin permisos IAM adicionales. No
// requiere sesión de Firebase; la protege el MIGRATION_TOKEN del payload.
export const runMigrations = onCall(
  {
    secrets: [MIGRATION_TOKEN],
    timeoutSeconds: 540,
    memory: "512MiB",
    maxInstances: 1,
    concurrency: 1,
  },
  async (request) => {
    const data = isPlainObject(request.data) ? request.data : {};
    if (!isAuthorized(data.token)) {
      throw new HttpsError("permission-denied", "No autorizado.");
    }
    const dryRun = data.dryRun !== false;
    let renames;
    try {
      renames = parseLoginRenames(data.renameLogins);
    } catch (error) {
      throw new HttpsError(
        "invalid-argument",
        error instanceof Error ? error.message : "renameLogins inválido",
      );
    }
    try {
      const db = getFirestore();
      const auth = getAuth();
      // Primero las cuentas antiguas con correo real pasan a usuario@cmo.com.
      const loginRenames = await applyLoginRenames(db, auth, renames, dryRun);
      const report = {...await runMigration(db, auth, dryRun), loginRenames};
      logger.info("Migración finalizada", report);
      return report;
    } catch (error) {
      logger.error("La migración falló", describeError(error));
      throw new HttpsError("internal", "La migración falló.");
    }
  },
);
