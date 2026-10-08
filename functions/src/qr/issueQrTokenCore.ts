import {QR_REFRESH_AFTER_MS, QR_TOKEN_TTL_MS} from "../constants";
import {findActiveMissions, MissionRecord} from "../missions/schedule";
import {signQrToken} from "./token";

export type IssueQrResult =
  | {
      status: "ok";
      token: string;
      missionId: string;
      missionName: string;
      issuedAt: number;
      expiresAt: number;
      refreshAfterMs: number;
    }
  | {status: "noActiveMission"}
  | {status: "chooseMission"; missions: {id: string; name: string}[]};

export interface IssueQrContext {
  nowMs: number;
  secret: string;
  presenterUid: string;
  nonce: string;
}

/**
 * Decide qué misión firmar con la hora del servidor.
 * @param {MissionRecord[]} missions Catálogo completo.
 * @param {string | null} requestedMissionId Misión elegida (opcional).
 * @param {IssueQrContext} ctx Reloj, secreto, presentador y nonce.
 * @return {IssueQrResult} Resultado del contrato.
 */
export function decideQrIssue(
  missions: MissionRecord[],
  requestedMissionId: string | null,
  ctx: IssueQrContext,
): IssueQrResult {
  const active = findActiveMissions(missions, ctx.nowMs);
  let chosen = active[0];
  if (requestedMissionId !== null) {
    const match = active.find((m) => m.id === requestedMissionId);
    if (!match) return {status: "noActiveMission"};
    chosen = match;
  } else if (active.length === 0) {
    return {status: "noActiveMission"};
  } else if (active.length > 1) {
    return {
      status: "chooseMission",
      missions: active.map((m) => ({id: m.id, name: m.name})),
    };
  }

  const issuedAt = ctx.nowMs;
  const expiresAt = issuedAt + QR_TOKEN_TTL_MS;
  const token = signQrToken({
    v: 1,
    m: chosen.id,
    iat: issuedAt,
    exp: expiresAt,
    n: ctx.nonce,
    p: ctx.presenterUid,
  }, ctx.secret);
  return {
    status: "ok",
    token,
    missionId: chosen.id,
    missionName: chosen.name,
    issuedAt,
    expiresAt,
    refreshAfterMs: QR_REFRESH_AFTER_MS,
  };
}
