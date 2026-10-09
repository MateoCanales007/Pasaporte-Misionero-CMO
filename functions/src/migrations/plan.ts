// Planificador puro de la migración: decide qué escribir sin tocar Firebase.
// Reglas: aditiva, idempotente, nunca borra, nunca baja un rol.
import {DEFAULT_MISSION_NAME} from "../constants";
import {Role, roleFromClaims} from "../core/roles";
import {Data, isPlainObject} from "../core/validation";
import {missionName} from "../missions/schedule";
import {DEFAULT_NOTIFICATION_PREFS} from "../notifications/topics";
import {summarizeLegacyStamps} from "../passport/legacyStamps";
import {LegacyRedemptionIntent} from "../qr/redeemStampCore";

export interface PlannerUser {
  uid: string;
  data: Data;
  redemptionIds: string[];
  /** null = no existe en Firebase Auth. */
  authUser: {claims: Record<string, unknown>} | null;
}

export interface PlannerMission {
  id: string;
  data: Data;
}

export interface ClaimUpdate {
  uid: string;
  role: Role;
  claims: Record<string, unknown>;
}

export interface PassportPatch {
  uid: string;
  /** Se aplica con set(..., {merge: true}); los mapas se fusionan. */
  set: Data;
  incrementRoleVersion: boolean;
}

export interface MissionStatusUpdate {
  missionId: string;
  status: "active" | "inactive";
}

export interface MigrationStats {
  users: number;
  usersWithLegacyStamps: number;
  legacyEntries: number;
  invalidLegacyEntries: number;
  redemptionsExisting: number;
  redemptionsToCreate: number;
  unknownMissionRefs: number;
  corruptedDates: number;
  claimsToSet: {admin: number; qrPresenter: number};
  roleMirrorsToSet: number;
  authUsersMissing: number;
  userDefaultsUpdated: number;
  missionsStatusSet: number;
}

export interface MigrationPlan {
  claimUpdates: ClaimUpdate[];
  passportPatches: PassportPatch[];
  redemptionCreates: LegacyRedemptionIntent[];
  missionStatusUpdates: MissionStatusUpdate[];
  stats: MigrationStats;
}

const PREF_KEYS = Object.keys(DEFAULT_NOTIFICATION_PREFS) as
  (keyof typeof DEFAULT_NOTIFICATION_PREFS)[];

/**
 * Rol deseado según los campos heredados.
 * @param {Data} data user_passport/{uid}.
 * @return {Role | null} admin, qrPresenter o null.
 */
export function legacyDesiredRole(data: Data): Role | null {
  if (data.isAdmin === true) return "admin";
  if (data.canShowQR === true) return "qrPresenter";
  return null;
}

/**
 * Campos por defecto faltantes (solo agrega; no reemplaza valores).
 * @param {Data} data user_passport/{uid}.
 * @return {Data} Campos a fusionar.
 */
export function missingDefaults(data: Data): Data {
  const set: Data = {};
  if (data.communityVisible === undefined) set.communityVisible = true;
  if (data.showNationality === undefined) set.showNationality = false;
  if (data.showCell === undefined) set.showCell = true;
  if (data.notificationPrefs === undefined) {
    set.notificationPrefs = {...DEFAULT_NOTIFICATION_PREFS};
  } else if (isPlainObject(data.notificationPrefs)) {
    const prefs = data.notificationPrefs;
    const missing: Data = {};
    for (const key of PREF_KEYS) {
      if (prefs[key] === undefined) missing[key] = true;
    }
    if (Object.keys(missing).length > 0) set.notificationPrefs = missing;
  }
  return set;
}

/**
 * Calcula el plan completo de migración.
 * @param {PlannerUser[]} users Perfiles con canjes y claims.
 * @param {PlannerMission[]} missions Catálogo stamp/.
 * @return {MigrationPlan} Escrituras necesarias y estadísticas.
 */
export function planMigration(
  users: PlannerUser[],
  missions: PlannerMission[],
): MigrationPlan {
  const catalog = new Map(missions.map((m) => [m.id, m.data]));
  const plan: MigrationPlan = {
    claimUpdates: [],
    passportPatches: [],
    redemptionCreates: [],
    missionStatusUpdates: [],
    stats: {
      users: users.length,
      usersWithLegacyStamps: 0,
      legacyEntries: 0,
      invalidLegacyEntries: 0,
      redemptionsExisting: 0,
      redemptionsToCreate: 0,
      unknownMissionRefs: 0,
      corruptedDates: 0,
      claimsToSet: {admin: 0, qrPresenter: 0},
      roleMirrorsToSet: 0,
      authUsersMissing: 0,
      userDefaultsUpdated: 0,
      missionsStatusSet: 0,
    },
  };
  const stats = plan.stats;

  for (const user of users) {
    const data = user.data;
    const set: Data = {};
    let incrementRoleVersion = false;

    // a. Roles: nunca se baja un rol ni se toca a un admin existente.
    if (!user.authUser) {
      stats.authUsersMissing++;
    } else {
      const current = roleFromClaims(user.authUser.claims);
      const desired = legacyDesiredRole(data);
      let effective = current;
      if (desired && current !== desired && current !== "admin") {
        plan.claimUpdates.push({
          uid: user.uid,
          role: desired,
          claims: {...user.authUser.claims, role: desired},
        });
        stats.claimsToSet[desired]++;
        effective = desired;
      }
      if (effective && data.role !== effective) {
        set.role = effective;
        incrementRoleVersion = true;
        stats.roleMirrorsToSet++;
      }
    }

    // b. Canjes heredados → redemptions/{missionId}.
    const legacy = summarizeLegacyStamps(data);
    stats.legacyEntries += legacy.validEntries;
    stats.invalidLegacyEntries += legacy.invalidEntries;
    if (legacy.stamps.size > 0) stats.usersWithLegacyStamps++;
    const existing = new Set(user.redemptionIds);
    for (const stamp of legacy.stamps.values()) {
      const mission = catalog.get(stamp.missionId);
      if (!mission) stats.unknownMissionRefs++;
      if (stamp.redeemedAtMs === null) stats.corruptedDates++;
      if (existing.has(stamp.missionId)) {
        stats.redemptionsExisting++;
        continue;
      }
      stats.redemptionsToCreate++;
      plan.redemptionCreates.push({
        source: "legacy_migration",
        missionId: stamp.missionId,
        userId: user.uid,
        missionName: mission ? missionName(mission) : DEFAULT_MISSION_NAME,
        redeemedAtMs: stamp.redeemedAtMs,
      });
    }

    // c. Valores por defecto y contador.
    const defaults = missingDefaults(data);
    const union = new Set([...existing, ...legacy.stamps.keys()]);
    if (data.stampCount !== union.size) defaults.stampCount = union.size;
    if (Object.keys(defaults).length > 0) stats.userDefaultsUpdated++;
    Object.assign(set, defaults);

    if (Object.keys(set).length > 0) {
      plan.passportPatches.push({uid: user.uid, set, incrementRoleVersion});
    }
  }

  // d. Misiones heredadas sin status.
  for (const mission of missions) {
    if (mission.data.status !== undefined) continue;
    plan.missionStatusUpdates.push({
      missionId: mission.id,
      status: mission.data.active === true ? "active" : "inactive",
    });
    stats.missionsStatusSet++;
  }
  return plan;
}

/**
 * @param {MigrationPlan} plan Plan.
 * @return {number} Total de escrituras (claims + documentos).
 */
export function plannedWriteCount(plan: MigrationPlan): number {
  return plan.claimUpdates.length +
    plan.passportPatches.length +
    plan.redemptionCreates.length +
    plan.missionStatusUpdates.length;
}
