// Prueba de integración de punta a punta contra los emuladores de Auth, Firestore y Functions.
// Contrato: docs/ARQUITECTURA.md (secciones 2, 3, 5 y 6).
//
// - Los usuarios y sus claims se siembran con firebase-admin (apuntando a los emuladores).
// - Las llamadas se hacen con el SDK cliente de Firebase, como lo haría la app.
// - Requiere `npm --prefix ../../functions run build` y functions/.secret.local con
//   QR_SIGNING_SECRET y MIGRATION_TOKEN (valores ficticios).
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_ID = 'demo-pasaporte-test';
const REGION = 'us-central1';

// Valores por defecto si no se ejecuta con `firebase emulators:exec` (que ya los define).
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.GCLOUD_PROJECT ??= PROJECT_ID;

const FUNCTIONS_HOST = '127.0.0.1';
const FUNCTIONS_PORT = 5001;
const RUN_MIGRATIONS_URL = `http://${FUNCTIONS_HOST}:${FUNCTIONS_PORT}/${PROJECT_ID}/${REGION}/runMigrations`;

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(here, '..', '..', '..');
const SECRET_FILE = path.join(REPO_ROOT, 'functions', '.secret.local');

// Importaciones dinámicas después de fijar las variables de entorno de los emuladores.
const { initializeApp: initAdminApp, deleteApp: deleteAdminApp } = await import('firebase-admin/app');
const { getAuth: getAdminAuth } = await import('firebase-admin/auth');
const { getFirestore: getAdminFirestore, Timestamp } = await import('firebase-admin/firestore');
const { initializeApp, deleteApp } = await import('firebase/app');
const { connectAuthEmulator, getAuth, signInWithEmailAndPassword, signOut } = await import('firebase/auth');
const { connectFunctionsEmulator, getFunctions, httpsCallable } = await import('firebase/functions');

function readSecretLocal(name) {
  if (!existsSync(SECRET_FILE)) return null;
  for (const raw of readFileSync(SECRET_FILE, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    if (line.slice(0, eq).trim() !== name) continue;
    let value = line.slice(eq + 1).trim();
    if (/^(['"]).*\1$/.test(value)) value = value.slice(1, -1);
    return value;
  }
  return null;
}

const MIGRATION_TOKEN = readSecretLocal('MIGRATION_TOKEN');

const PASSWORD = 'Integracion-2026!';
const USERS = {
  admin: { uid: 'it-admin', username: 'itadmin', claims: { role: 'admin' } },
  presenter: { uid: 'it-presenter', username: 'itpresenter', claims: { role: 'qrPresenter' } },
  user: { uid: 'it-user', username: 'ituser', claims: null },
  legacy: { uid: 'it-legacy', username: 'itlegacy', claims: null },
};
const LEGACY_MISSION_ID = 'it-legacy-mission';
const LEGACY_DATE = Timestamp.fromDate(new Date('2025-03-15T15:30:00Z'));

let adminApp;
let adminAuth;
let adminDb;
const clients = {}; // nombre -> { app, auth, functions }
let createdMissionId;
let issuedToken;

function passportFor(key, extra = {}) {
  const u = USERS[key];
  return {
    id: u.uid,
    username: u.username,
    passportNumber: `PM-2026-${u.uid.slice(3, 7).toUpperCase()}`,
    fullName: `Prueba ${key}`,
    nationality: 'El Salvador',
    dateOfBirth: '1999-12-31T00:00:00.000',
    cellId: '',
    dateOfIssue: '2026-01-01T00:00:00.000',
    stamps: [],
    communityVisible: true,
    showNationality: false,
    showCell: true,
    ...extra,
  };
}

async function ensureUser(key) {
  const u = USERS[key];
  const email = `${u.username}@cmo.com`;
  try {
    await adminAuth.deleteUser(u.uid);
  } catch {
    // no existía
  }
  await adminAuth.createUser({ uid: u.uid, email, password: PASSWORD, emailVerified: true });
  if (u.claims) await adminAuth.setCustomUserClaims(u.uid, u.claims);
}

async function signedInClient(key) {
  const u = USERS[key];
  const app = initializeApp(
    { apiKey: 'demo-api-key', projectId: PROJECT_ID, authDomain: `${PROJECT_ID}.firebaseapp.com` },
    `client-${key}-${Date.now()}`,
  );
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
  await signInWithEmailAndPassword(auth, `${u.username}@cmo.com`, PASSWORD);
  const functions = getFunctions(app, REGION);
  connectFunctionsEmulator(functions, FUNCTIONS_HOST, FUNCTIONS_PORT);
  clients[key] = { app, auth, functions };
  return clients[key];
}

async function call(key, name, data = {}) {
  const fn = httpsCallable(clients[key].functions, name, { timeout: 70_000 });
  const res = await fn(data);
  return res.data;
}

function isCode(code) {
  return (err) => {
    assert.equal(err?.code, `functions/${code}`, `se esperaba ${code}, llegó ${err?.code}: ${err?.message}`);
    return true;
  };
}

// Cambia un carácter en medio de la firma (no el último: en base64url sin relleno los bits
// finales pueden no alterar los bytes decodificados).
function tamperSignature(token) {
  const parts = token.split('.');
  const sig = parts[2];
  const i = Math.floor(sig.length / 2);
  const replacement = sig[i] === 'A' ? 'B' : 'A';
  parts[2] = sig.slice(0, i) + replacement + sig.slice(i + 1);
  return parts.join('.');
}

// runMigrations es una callable: protocolo {data} → {result} | {error}.
async function callMigration(data) {
  const res = await fetch(RUN_MIGRATIONS_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    // respuesta no JSON
  }
  return { status: res.status, json: parsed?.result ?? null, error: parsed?.error ?? null, text };
}

const postMigration = (body) => callMigration({ token: MIGRATION_TOKEN, ...body });

// Huella de los documentos que escribe la migración: user_passport y sus canjes.
async function migrationFootprint() {
  const out = new Map();
  const passports = await adminDb.collection('user_passport').get();
  for (const d of passports.docs) {
    out.set(d.ref.path, d.updateTime.toMillis());
    const reds = await d.ref.collection('redemptions').get();
    for (const r of reds.docs) out.set(r.ref.path, r.updateTime.toMillis());
  }
  return out;
}

async function claimsOf(uid) {
  return (await adminAuth.getUser(uid)).customClaims ?? {};
}

before(async () => {
  adminApp = initAdminApp({ projectId: PROJECT_ID }, `it-admin-${Date.now()}`);
  adminAuth = getAdminAuth(adminApp);
  adminDb = getAdminFirestore(adminApp);

  for (const key of Object.keys(USERS)) await ensureUser(key);

  const batch = adminDb.batch();
  batch.set(adminDb.doc(`user_passport/${USERS.admin.uid}`), passportFor('admin', { role: 'admin', isAdmin: true }));
  batch.set(
    adminDb.doc(`user_passport/${USERS.presenter.uid}`),
    passportFor('presenter', { role: 'qrPresenter', canShowQR: true }),
  );
  batch.set(adminDb.doc(`user_passport/${USERS.user.uid}`), passportFor('user', { role: 'user' }));
  batch.set(adminDb.doc(`stamp/${LEGACY_MISSION_ID}`), {
    name: 'Misión heredada',
    isoCode: 'GT',
    image: '',
    active: false,
  });
  await batch.commit();

  for (const key of ['admin', 'presenter', 'user']) await signedInClient(key);
});

after(async () => {
  for (const c of Object.values(clients)) {
    try {
      await signOut(c.auth);
    } catch {
      // ignorar
    }
    await deleteApp(c.app);
  }
  if (adminApp) await deleteAdminApp(adminApp);
});

describe('flujo QR de punta a punta', () => {
  test('el admin crea una misión activa con saveMission', async () => {
    const now = Date.now();
    const res = await call('admin', 'saveMission', {
      name: 'Misión Integración',
      isoCode: 'SV',
      image: '',
      location: { lat: 13.6929, lng: -89.2182 },
      schedules: [{ start: now - 60 * 60 * 1000, end: now + 2 * 60 * 60 * 1000 }],
      status: 'active',
    });
    assert.equal(typeof res.missionId, 'string');
    assert.ok(res.missionId.length > 0);
    createdMissionId = res.missionId;

    const snap = await adminDb.doc(`stamp/${createdMissionId}`).get();
    assert.ok(snap.exists, 'la misión debe existir en stamp/');
    assert.equal(snap.get('status'), 'active');
    assert.equal(snap.get('active'), true);
    assert.equal(snap.get('createdBy'), USERS.admin.uid);
  });

  test('el presentador emite un token QR', async () => {
    assert.ok(createdMissionId, 'requiere la misión creada');
    const res = await call('presenter', 'issueQrToken', { missionId: createdMissionId });
    assert.equal(res.status, 'ok', JSON.stringify(res));
    assert.equal(res.missionId, createdMissionId);
    assert.equal(res.missionName, 'Misión Integración');
    assert.ok(res.token.startsWith('PMCMO1.'), res.token);
    assert.equal(res.token.split('.').length, 3);
    assert.equal(res.expiresAt - res.issuedAt, 60_000);
    assert.equal(res.refreshAfterMs, 30_000);
    issuedToken = res.token;
  });

  test('el usuario canjea el token: confirmed', async () => {
    assert.ok(issuedToken, 'requiere el token emitido');
    const res = await call('user', 'redeemStamp', {
      token: issuedToken,
      appVersion: '2.0.0-test',
      platform: 'android',
    });
    assert.equal(res.status, 'confirmed', JSON.stringify(res));
    assert.equal(res.missionId, createdMissionId);
    assert.equal(res.missionName, 'Misión Integración');
    assert.equal(typeof res.redeemedAt, 'number');
  });

  test('el canje queda en user_passport/{uid}/redemptions/{missionId}', async () => {
    const snap = await adminDb
      .doc(`user_passport/${USERS.user.uid}/redemptions/${createdMissionId}`)
      .get();
    assert.ok(snap.exists, 'el documento de canje debe existir');
    const r = snap.data();
    assert.equal(r.source, 'qr');
    assert.equal(r.status, 'confirmed');
    assert.equal(r.validatedBy, USERS.presenter.uid);
    assert.equal(r.userId, USERS.user.uid);
    assert.equal(r.missionId, createdMissionId);
    assert.equal(r.missionName, 'Misión Integración');
    assert.equal(typeof r.tokenId, 'string');
    assert.ok(r.redeemedAt instanceof Timestamp);

    const passport = await adminDb.doc(`user_passport/${USERS.user.uid}`).get();
    assert.equal(passport.get('stampCount'), 1);
  });

  test('un segundo canje devuelve alreadyRedeemed', async () => {
    const res = await call('user', 'redeemStamp', { token: issuedToken });
    assert.equal(res.status, 'alreadyRedeemed', JSON.stringify(res));
    assert.equal(res.missionId, createdMissionId);
    const passport = await adminDb.doc(`user_passport/${USERS.user.uid}`).get();
    assert.equal(passport.get('stampCount'), 1, 'el contador no debe aumentar');
  });

  test('un token con la firma alterada devuelve invalid', async () => {
    const res = await call('user', 'redeemStamp', { token: tamperSignature(issuedToken) });
    assert.deepEqual(res, { status: 'invalid' });
  });

  test('un texto que no es un token devuelve invalid', async () => {
    const res = await call('user', 'redeemStamp', { token: 'https://example.com/no-es-un-qr' });
    assert.deepEqual(res, { status: 'invalid' });
  });
});

describe('permisos de las callables', () => {
  test('un usuario normal no puede emitir QR (permission-denied)', async () => {
    await assert.rejects(
      call('user', 'issueQrToken', { missionId: createdMissionId }),
      isCode('permission-denied'),
    );
  });

  test('el presentador no puede guardar misiones (permission-denied)', async () => {
    const now = Date.now();
    await assert.rejects(
      call('presenter', 'saveMission', {
        name: 'Misión no autorizada',
        isoCode: 'HN',
        image: '',
        location: { lat: 14.1, lng: -87.2 },
        schedules: [{ start: now, end: now + 3_600_000 }],
        status: 'draft',
      }),
      isCode('permission-denied'),
    );
  });

  test('un usuario normal no puede asignar roles (permission-denied)', async () => {
    await assert.rejects(
      call('user', 'setUserRole', { uid: USERS.user.uid, role: 'qrPresenter' }),
      isCode('permission-denied'),
    );
  });

  test('el admin asigna qrPresenter con setUserRole y el claim queda en Auth', async () => {
    const res = await call('admin', 'setUserRole', { uid: USERS.user.uid, role: 'qrPresenter' });
    assert.deepEqual(res, { uid: USERS.user.uid, role: 'qrPresenter' });
    const claims = await claimsOf(USERS.user.uid);
    assert.equal(claims.role, 'qrPresenter');
    const passport = await adminDb.doc(`user_passport/${USERS.user.uid}`).get();
    assert.equal(passport.get('role'), 'qrPresenter', 'el rol se refleja en user_passport');
    assert.equal(typeof passport.get('roleVersion'), 'number');
  });
});

describe('migración heredada (runMigrations)', () => {
  const legacyRedemptionPath = () =>
    `user_passport/${USERS.legacy.uid}/redemptions/${LEGACY_MISSION_ID}`;

  before(async () => {
    // Documento con la forma antigua: stamps[] y canShowQR, sin role/roleVersion/stampCount.
    await adminDb.doc(`user_passport/${USERS.legacy.uid}`).set({
      id: USERS.legacy.uid,
      username: USERS.legacy.username,
      passportNumber: 'PM-2025-LEGA',
      fullName: 'Usuario Heredado',
      nationality: 'Guatemala',
      dateOfBirth: '1990-07-20T00:00:00.000',
      cellId: 'Célula Centro',
      dateOfIssue: '2025-01-10T00:00:00.000',
      stamps: [{ stampId: LEGACY_MISSION_ID, dateObtained: LEGACY_DATE }],
      isAdmin: false,
      canShowQR: true,
    });
  });

  test('MIGRATION_TOKEN está disponible en functions/.secret.local', () => {
    assert.ok(MIGRATION_TOKEN, `falta MIGRATION_TOKEN en ${SECRET_FILE}`);
  });

  test('sin el token correcto la migración se rechaza', async () => {
    const res = await callMigration({ token: 'token-incorrecto', dryRun: false });
    assert.equal(res.status, 403, res.text);
    assert.equal(res.error?.status, 'PERMISSION_DENIED');
    assert.equal((await adminDb.doc(legacyRedemptionPath()).get()).exists, false);
  });

  test('dryRun: true no escribe nada', async () => {
    const before = await migrationFootprint();
    const claimsBefore = await claimsOf(USERS.legacy.uid);
    const res = await postMigration({ dryRun: true });
    assert.equal(res.status, 200, res.text);
    // El contrato no fija la forma del reporte; si trae estos campos, deben cuadrar.
    if (res.json && 'dryRun' in res.json) assert.equal(res.json.dryRun, true);
    if (res.json && typeof res.json.redemptionsToCreate === 'number') {
      assert.ok(res.json.redemptionsToCreate >= 1, 'el reporte debe anunciar el canje pendiente');
    }

    assert.equal((await adminDb.doc(legacyRedemptionPath()).get()).exists, false);
    assert.deepEqual(await claimsOf(USERS.legacy.uid), claimsBefore);
    assert.deepEqual(await migrationFootprint(), before, 'dryRun no debe modificar documentos');
  });

  test('dryRun: false crea el canje heredado y asigna el claim', async () => {
    const res = await postMigration({ dryRun: false });
    assert.equal(res.status, 200, res.text);

    const red = await adminDb.doc(legacyRedemptionPath()).get();
    assert.ok(red.exists, 'debe crearse el canje heredado');
    assert.equal(red.get('source'), 'legacy_migration');
    assert.equal(red.get('status'), 'confirmed');
    assert.equal(red.get('userId'), USERS.legacy.uid);
    assert.equal(red.get('missionId'), LEGACY_MISSION_ID);
    assert.ok(red.get('redeemedAt') instanceof Timestamp);
    assert.equal(red.get('redeemedAt').toMillis(), LEGACY_DATE.toMillis());

    const claims = await claimsOf(USERS.legacy.uid);
    assert.equal(claims.role, 'qrPresenter', 'canShowQR heredado => claim qrPresenter');

    const passport = await adminDb.doc(`user_passport/${USERS.legacy.uid}`).get();
    assert.equal(passport.get('role'), 'qrPresenter', 'el rol se refleja en user_passport');
    // El contrato no obliga a la migración a calcular stampCount; si lo escribe, debe cuadrar.
    const stampCount = passport.get('stampCount');
    if (stampCount !== undefined) assert.equal(stampCount, 1);
    assert.deepEqual(
      passport.get('stamps'),
      [{ stampId: LEGACY_MISSION_ID, dateObtained: LEGACY_DATE }],
      'los campos heredados no se borran',
    );
  });

  test('una segunda ejecución es idempotente (cero escrituras nuevas)', async () => {
    const before = await migrationFootprint();
    const claimsBefore = await claimsOf(USERS.legacy.uid);
    const res = await postMigration({ dryRun: false });
    assert.equal(res.status, 200, res.text);
    assert.deepEqual(await migrationFootprint(), before, 'no debe reescribir documentos');
    if (res.json && typeof res.json.redemptionsCreated === 'number') {
      assert.equal(res.json.redemptionsCreated, 0);
    }
    if (res.json?.verification && typeof res.json.verification.pendingWrites === 'number') {
      assert.equal(res.json.verification.pendingWrites, 0);
    }
    assert.deepEqual(await claimsOf(USERS.legacy.uid), claimsBefore);
  });
});
