// Se importa primero desde index.ts: inicializa Admin SDK y opciones globales.
import {getApps, initializeApp} from "firebase-admin/app";
import {setGlobalOptions} from "firebase-functions/v2";
import {REGION} from "./constants";

if (getApps().length === 0) {
  initializeApp();
}

setGlobalOptions({region: REGION, maxInstances: 10});
