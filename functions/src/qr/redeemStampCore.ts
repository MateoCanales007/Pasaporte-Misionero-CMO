import {QR_REDEEM_GRACE_MS, QR_TOKEN_PREFIX} from "../constants";
import {DomainError} from "../core/errors";
import {timestampToMillis} from "../core/time";
import {Data, isPlainObject} from "../core/validation";
import {
  isMissionActive,
  isWithinAnyWindow,
  missionName,
  parseStoredSchedule,
} from "../missions/schedule";
import {summarizeLegacyStamps} from "../passport/legacyStamps";
import {verifyQrToken} from "./token";

export type RedeemResult =
  | {
      status: "confirmed" | "alreadyRedeemed";
      missionId: string;
      missionName: string;
      redeemedAt: number | null;
    }
  | {status: "expired" | "invalid" | "notFound"}
  | {status: "inactive" | "outsideSchedule"; missionName: string};

export interface QrRedemptionIntent {
  source: "qr";
  missionId: string;
  userId: string;
  missionName: string;
  tokenId: string;
  tokenIssuedAtMs: number;
  validatedBy: string;
  appVersion: string | null;
  platform: string | null;
}

export interface LegacyRedemptionIntent {
  source: "legacy_migration";
  missionId: string;
  userId: string;
  missionName: string;
  redeemedAtMs: number | null;
}

export type RedemptionIntent = QrRedemptionIntent | LegacyRedemptionIntent;

/** Operaciones disponibles dentro de la transacción (lecturas primero). */
export interface RedeemTransaction {
  getMission(missionId: string): Promise<Data | null>;
  getUserPassport(uid: string): Promise<Data | null>;
  getRedemption(uid: string, missionId: string): Promise<Data | null>;
  createRedemption(intent: RedemptionIntent): void;
  recordStampConfirmed(uid: string): void;
}

export interface RedeemRepository {
  runTransaction<T>(fn: (tx: RedeemTransaction) => Promise<T>): Promise<T>;
}

export interface RedeemDeps {
  repo: RedeemRepository;
  now: () => number;
  secret: string;
  graceMs?: number;
}

export interface RedeemInput {
  uid: string;
  token: string;
  appVersion: string | null;
  platform: string | null;
}

export interface RedeemOutcome {
  result: RedeemResult;
  notifyStampConfirmed: boolean;
}

export const PROFILE_REQUIRED_MESSAGE = "Completa tu perfil primero";

/**
 * Canjea un QR: valida token, misión, horario (con iat) y duplicados en una
 * transacción. No depende de Firebase para poder probarse.
 * @param {RedeemDeps} deps Repositorio, reloj y secreto.
 * @param {RedeemInput} input Usuario y token.
 * @return {Promise<RedeemOutcome>} Resultado del contrato.
 */
export async function redeemStampCore(
  deps: RedeemDeps,
  input: RedeemInput,
): Promise<RedeemOutcome> {
  const quiet = (result: RedeemResult): RedeemOutcome =>
    ({result, notifyStampConfirmed: false});

  if (!input.token.startsWith(`${QR_TOKEN_PREFIX}.`)) {
    return quiet({status: "invalid"});
  }
  const verified = verifyQrToken(
    input.token,
    deps.secret,
    deps.now(),
    deps.graceMs ?? QR_REDEEM_GRACE_MS,
  );
  if (!verified.ok) {
    return quiet({
      status: verified.reason === "expired" ? "expired" : "invalid",
    });
  }
  const payload = verified.payload;
  const missionId = payload.m;

  return deps.repo.runTransaction(async (tx) => {
    const mission = await tx.getMission(missionId);
    if (!mission) return quiet({status: "notFound"});
    const name = missionName(mission);
    if (!isMissionActive(mission)) {
      return quiet({status: "inactive", missionName: name});
    }
    const windows = parseStoredSchedule(mission.schedule);
    if (!isWithinAnyWindow(windows, payload.iat)) {
      return quiet({status: "outsideSchedule", missionName: name});
    }

    const passport = await tx.getUserPassport(input.uid);
    if (!passport) {
      throw new DomainError("failed-precondition", PROFILE_REQUIRED_MESSAGE);
    }
    const existing = await tx.getRedemption(input.uid, missionId);
    if (existing) {
      return quiet({
        status: "alreadyRedeemed",
        missionId,
        missionName: typeof existing.missionName === "string" ?
          existing.missionName :
          name,
        redeemedAt: timestampToMillis(existing.redeemedAt),
      });
    }

    const legacy = summarizeLegacyStamps(passport).stamps.get(missionId);
    if (legacy) {
      const redeemedAtMs = legacy.redeemedAtMs;
      tx.createRedemption({
        source: "legacy_migration",
        missionId,
        userId: input.uid,
        missionName: name,
        redeemedAtMs,
      });
      return quiet({
        status: "alreadyRedeemed",
        missionId,
        missionName: name,
        redeemedAt: redeemedAtMs,
      });
    }

    tx.createRedemption({
      source: "qr",
      missionId,
      userId: input.uid,
      missionName: name,
      tokenId: payload.n,
      tokenIssuedAtMs: payload.iat,
      validatedBy: payload.p,
      appVersion: input.appVersion,
      platform: input.platform,
    });
    tx.recordStampConfirmed(input.uid);
    const prefs = isPlainObject(passport.notificationPrefs) ?
      passport.notificationPrefs :
      {};
    return {
      result: {
        status: "confirmed",
        missionId,
        missionName: name,
        redeemedAt: deps.now(),
      },
      notifyStampConfirmed: prefs.stampConfirmed !== false,
    };
  });
}
