/** Entrada inválida; se traduce a HttpsError "invalid-argument". */
export class ValidationError extends Error {
  /**
   * @param {string} message Mensaje para el usuario.
   * @param {string} field Campo que no pasó la validación.
   */
  constructor(message: string, readonly field: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export type DomainErrorCode =
  | "failed-precondition"
  | "not-found"
  | "permission-denied";

/** Regla de negocio violada; se traduce al HttpsError del mismo código. */
export class DomainError extends Error {
  /**
   * @param {string} code Código HttpsError.
   * @param {string} message Mensaje para el usuario.
   */
  constructor(readonly code: DomainErrorCode, message: string) {
    super(message);
    this.name = "DomainError";
  }
}

/**
 * Extrae el código de un error de Firebase/Google sin asumir su tipo.
 * @param {unknown} error Error capturado.
 * @return {string | number | undefined} Código si existe.
 */
export function errorCode(error: unknown): string | number | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = (error as {code: unknown}).code;
    if (typeof code === "string" || typeof code === "number") return code;
  }
  return undefined;
}

/**
 * Descripción segura para logs (sin stack ni datos de la solicitud).
 * @param {unknown} error Error capturado.
 * @return {object} Nombre, mensaje y código.
 */
export function describeError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return {name: error.name, message: error.message, code: errorCode(error)};
  }
  return {value: String(error)};
}
