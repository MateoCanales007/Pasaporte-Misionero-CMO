import * as logger from "firebase-functions/logger";
import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK, Secret} from "../config";
import {describeError, DomainError, ValidationError} from "./errors";

/**
 * Traduce errores de dominio a HttpsError; lo inesperado queda en logs.
 * @param {unknown} error Error capturado.
 * @return {HttpsError} Error para el cliente.
 */
export function toHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof ValidationError) {
    return new HttpsError("invalid-argument", error.message, {
      field: error.field,
    });
  }
  if (error instanceof DomainError) {
    return new HttpsError(error.code, error.message);
  }
  logger.error("Error inesperado en callable", describeError(error));
  return new HttpsError(
    "internal",
    "Ocurrió un error inesperado. Intenta de nuevo.",
  );
}

/**
 * Callable con App Check configurable y traducción uniforme de errores.
 * @param {Function} handler Lógica de la función.
 * @param {Secret[]} secrets Secretos que necesita.
 * @return {CallableFunction} Función exportable.
 */
export function secureCallable<R>(
  handler: (request: CallableRequest<unknown>) => Promise<R>,
  secrets: Secret[] = [],
) {
  return onCall<unknown, Promise<R>>(
    {enforceAppCheck: ENFORCE_APP_CHECK, secrets},
    async (request) => {
      try {
        return await handler(request);
      } catch (error) {
        throw toHttpsError(error);
      }
    },
  );
}

/**
 * Lee un secreto y verifica que esté configurado (nunca lo registra).
 * @param {Secret} secret Parámetro de secreto.
 * @param {number} minLength Longitud mínima aceptada.
 * @return {string} Valor del secreto.
 */
export function readSecret(secret: Secret, minLength = 1): string {
  let value = "";
  try {
    value = secret.value() ?? "";
  } catch {
    value = "";
  }
  if (value.length < minLength) {
    logger.error(`El secreto ${secret.name} no está configurado.`);
    throw new HttpsError("internal", "El servicio no está configurado.");
  }
  return value;
}
