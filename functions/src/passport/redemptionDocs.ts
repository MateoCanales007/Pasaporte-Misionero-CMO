import {DocumentData, FieldValue, Timestamp} from "firebase-admin/firestore";
import {
  LegacyRedemptionIntent,
  QrRedemptionIntent,
  RedemptionIntent,
} from "../qr/redeemStampCore";

/**
 * Documento redemptions/{missionId} para un canje por QR.
 * @param {QrRedemptionIntent} intent Datos del canje.
 * @return {DocumentData} Documento a crear.
 */
export function qrRedemptionDoc(intent: QrRedemptionIntent): DocumentData {
  return {
    missionId: intent.missionId,
    userId: intent.userId,
    missionName: intent.missionName,
    status: "confirmed",
    source: "qr",
    redeemedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    tokenId: intent.tokenId,
    tokenIssuedAt: Timestamp.fromMillis(intent.tokenIssuedAtMs),
    validatedBy: intent.validatedBy,
    appVersion: intent.appVersion,
    platform: intent.platform,
  };
}

/**
 * Documento redemptions/{missionId} creado desde user_passport.stamps[].
 * @param {LegacyRedemptionIntent} intent Datos heredados.
 * @return {DocumentData} Documento a crear.
 */
export function legacyRedemptionDoc(
  intent: LegacyRedemptionIntent,
): DocumentData {
  const hasDate = intent.redeemedAtMs !== null;
  return {
    missionId: intent.missionId,
    userId: intent.userId,
    missionName: intent.missionName,
    status: "confirmed",
    source: "legacy_migration",
    redeemedAt: hasDate ?
      Timestamp.fromMillis(intent.redeemedAtMs as number) :
      null,
    legacyDateMissing: !hasDate,
    createdAt: FieldValue.serverTimestamp(),
    tokenId: null,
    tokenIssuedAt: null,
    validatedBy: null,
    appVersion: null,
    platform: null,
  };
}

/**
 * @param {RedemptionIntent} intent Canje QR o heredado.
 * @return {DocumentData} Documento a crear.
 */
export function redemptionDoc(intent: RedemptionIntent): DocumentData {
  return intent.source === "qr" ?
    qrRedemptionDoc(intent) :
    legacyRedemptionDoc(intent);
}
