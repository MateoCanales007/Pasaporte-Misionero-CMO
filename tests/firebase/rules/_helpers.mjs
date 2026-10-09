// Utilidades compartidas por las pruebas de reglas. No es un archivo de pruebas
// (no termina en .test.mjs), así que `node --test` no lo ejecuta por sí solo.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { setLogLevel } from 'firebase/firestore';

// Los PERMISSION_DENIED esperados se registran como advertencias del SDK; se ocultan para que la
// salida muestre solo el resultado de las pruebas. Usa FIREBASE_TEST_VERBOSE=1 para verlos.
if (!process.env.FIREBASE_TEST_VERBOSE) setLogLevel('error');

export const PROJECT_ID = 'demo-pasaporte-test';

const here = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(here, '..', '..', '..');

export function readRepoFile(name) {
  return readFileSync(path.join(REPO_ROOT, name), 'utf8');
}

// Usa las variables que define `firebase emulators:exec`; si no existen (emuladores levantados
// a mano con `firebase emulators:start`), cae en los puertos de firebase.json.
function emulatorAddress(envVar, defaultPort) {
  const value = process.env[envVar];
  if (value) {
    const sep = value.lastIndexOf(':');
    return { host: value.slice(0, sep), port: Number(value.slice(sep + 1)) };
  }
  return { host: '127.0.0.1', port: defaultPort };
}

export async function createFirestoreEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readRepoFile('firestore.rules'),
      ...emulatorAddress('FIRESTORE_EMULATOR_HOST', 8080),
    },
  });
}

export async function createStorageEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readRepoFile('storage.rules'),
      ...emulatorAddress('FIREBASE_STORAGE_EMULATOR_HOST', 9199),
    },
  });
}

// Contextos de autenticación usados en todas las pruebas.
export function buildContexts(testEnv) {
  return {
    unauth: testEnv.unauthenticatedContext(),
    alice: testEnv.authenticatedContext('alice', { email: 'alice@cmo.com' }),
    bob: testEnv.authenticatedContext('bob', { email: 'bob@cmo.com' }),
    carol: testEnv.authenticatedContext('carol', { email: 'carol@cmo.com' }),
    presenter: testEnv.authenticatedContext('presenter1', {
      email: 'presenter1@cmo.com',
      role: 'qrPresenter',
    }),
    admin: testEnv.authenticatedContext('admin1', { email: 'admin1@cmo.com', role: 'admin' }),
  };
}
