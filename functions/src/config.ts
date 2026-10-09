import {defineSecret} from "firebase-functions/params";

export * from "./constants";

export const QR_SIGNING_SECRET = defineSecret("QR_SIGNING_SECRET");
export const PLACES_API_KEY = defineSecret("PLACES_API_KEY");
export const MIGRATION_TOKEN = defineSecret("MIGRATION_TOKEN");

export type Secret = typeof QR_SIGNING_SECRET;

// Se lee de functions/.env (o .env.<proyecto>) al desplegar y en el emulador.
export const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";
