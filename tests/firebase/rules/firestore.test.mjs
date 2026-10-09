// Pruebas de firestore.rules contra el emulador de Firestore.
// Contrato: docs/ARQUITECTURA.md (secciones 2 y 3).
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { buildContexts, createFirestoreEnv } from './_helpers.mjs';

let testEnv;
let ctx;

// Instancias de Firestore por contexto.
const db = (name) => ctx[name].firestore();

const FIXED_CREATED_AT = Timestamp.fromDate(new Date('2026-09-01T12:00:00Z'));
const FIXED_ANNOUNCED_AT = Timestamp.fromDate(new Date('2026-09-01T12:05:00Z'));
const PUBLISHED_AT = Timestamp.fromDate(new Date('2026-10-01T18:00:00Z'));

const ALL_PREFS = {
  newMission: true,
  missionReminder: true,
  newSermon: true,
  stampConfirmed: true,
};

// Documento de pasaporte tal como lo dejaría la app + campos de servidor (sembrado sin reglas).
function seededPassport(uid, extra = {}) {
  return {
    id: uid,
    username: uid,
    passportNumber: `PM-2026-${uid.slice(0, 4).toUpperCase()}`,
    fullName: `${uid} Apellido`,
    nationality: 'El Salvador',
    dateOfBirth: '2000-01-01T00:00:00.000',
    cellId: 'cell1',
    dateOfIssue: '2026-01-01T00:00:00.000',
    stamps: [],
    communityVisible: true,
    showNationality: false,
    showCell: true,
    notificationPrefs: ALL_PREFS,
    role: 'user',
    roleVersion: 1,
    stampCount: 1,
    isAdmin: false,
    canShowQR: false,
    createdAt: FIXED_CREATED_AT,
    updatedAt: FIXED_CREATED_AT,
    ...extra,
  };
}

// Pasaporte válido que un usuario nuevo crea desde la app.
function newPassport(uid, overrides = {}) {
  return {
    id: uid,
    username: uid,
    passportNumber: 'PM-2026-CARO',
    fullName: 'Carol Pérez',
    nationality: 'El Salvador',
    dateOfBirth: '2001-05-01T00:00:00.000',
    cellId: 'cell1',
    dateOfIssue: '2026-10-06T10:00:00.000',
    stamps: [],
    communityVisible: true,
    showNationality: false,
    showCell: true,
    notificationPrefs: ALL_PREFS,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function seededSermon(extra = {}) {
  return {
    sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    title: 'La gran comisión',
    coverImageUrl: '',
    coverStoragePath: null,
    thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    platform: 'youtube',
    domain: 'youtube.com',
    externalVideoId: 'dQw4w9WgXcQ',
    publishedAt: PUBLISHED_AT,
    active: true,
    deleted: false,
    deletedAt: null,
    sortOrder: 0,
    createdBy: 'admin1',
    createdAt: FIXED_CREATED_AT,
    updatedBy: 'admin1',
    updatedAt: FIXED_CREATED_AT,
    ...extra,
  };
}

// Prédica válida creada por un admin desde la app.
function newSermon(uid = 'admin1', overrides = {}) {
  return {
    sourceUrl: 'https://www.youtube.com/watch?v=abc123XYZ00',
    title: 'Id y haced discípulos',
    coverImageUrl: '',
    coverStoragePath: null,
    thumbnailUrl: 'https://i.ytimg.com/vi/abc123XYZ00/hqdefault.jpg',
    platform: 'youtube',
    domain: 'youtube.com',
    externalVideoId: 'abc123XYZ00',
    publishedAt: PUBLISHED_AT,
    active: true,
    deleted: false,
    deletedAt: null,
    sortOrder: 1,
    createdBy: uid,
    createdAt: serverTimestamp(),
    updatedBy: uid,
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function newTestimonial(uid, overrides = {}) {
  return {
    userId: uid,
    displayName: 'Alice D.',
    text: 'Fue una experiencia que cambió mi vida.',
    missionId: 'm1',
    status: 'pending',
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    const fs = admin.firestore();
    const writes = [
      setDoc(doc(fs, 'user_passport/alice'), seededPassport('alice')),
      setDoc(doc(fs, 'user_passport/bob'), seededPassport('bob', { communityVisible: false })),
      setDoc(doc(fs, 'user_passport/alice/redemptions/m1'), {
        missionId: 'm1',
        userId: 'alice',
        missionName: 'Misión Guatemala',
        status: 'confirmed',
        source: 'qr',
        redeemedAt: FIXED_CREATED_AT,
        createdAt: FIXED_CREATED_AT,
        tokenId: 'nonce1',
        tokenIssuedAt: FIXED_CREATED_AT,
        validatedBy: 'presenter1',
        appVersion: '1.0.0',
        platform: 'android',
      }),
      setDoc(doc(fs, 'user_passport/bob/redemptions/m1'), {
        missionId: 'm1',
        userId: 'bob',
        missionName: 'Misión Guatemala',
        status: 'confirmed',
        source: 'legacy_migration',
        redeemedAt: FIXED_CREATED_AT,
        createdAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'user_passport/alice/journal/j1'), {
        text: 'Mi primer día de misión.',
        missionId: 'm1',
        missionName: 'Misión Guatemala',
        createdAt: FIXED_CREATED_AT,
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'user_passport/alice/fcm_tokens/tokenAlice1'), {
        token: 'tokenAlice1',
        platform: 'android',
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'public_profiles/alice'), {
        uid: 'alice',
        displayName: 'alice Apellido',
        initials: 'AA',
        cellName: 'Célula 1',
        nationality: null,
        stampCount: 1,
        stampIds: ['m1'],
        communityVisible: true,
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'public_profiles/bob'), {
        uid: 'bob',
        displayName: 'bob Apellido',
        initials: 'BA',
        cellName: null,
        nationality: null,
        stampCount: 1,
        stampIds: ['m1'],
        communityVisible: false,
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'public_profiles/dave'), {
        uid: 'dave',
        displayName: 'Dave Visible',
        initials: 'DV',
        cellName: null,
        nationality: 'Honduras',
        stampCount: 0,
        stampIds: [],
        communityVisible: true,
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'stamp/m1'), {
        name: 'Misión Guatemala',
        isoCode: 'GT',
        image: '',
        schedule: [],
        status: 'active',
        active: true,
        createdBy: 'admin1',
        updatedBy: 'admin1',
        createdAt: FIXED_CREATED_AT,
        updatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'cell/cell1'), { name: 'Célula 1' }),
      setDoc(doc(fs, 'sermons/sActive'), seededSermon({ announcedAt: FIXED_ANNOUNCED_AT })),
      setDoc(doc(fs, 'sermons/sInactive'), seededSermon({ active: false, title: 'Borrador' })),
      setDoc(doc(fs, 'testimonials/tBobPending'), {
        userId: 'bob',
        displayName: 'Bob',
        text: 'Testimonio pendiente de Bob.',
        missionId: null,
        status: 'pending',
        createdAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'testimonials/tBobApproved'), {
        userId: 'bob',
        displayName: 'Bob',
        text: 'Testimonio aprobado de Bob.',
        missionId: 'm1',
        status: 'approved',
        createdAt: FIXED_CREATED_AT,
        moderatedBy: 'admin1',
        moderatedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'testimonials/tAlicePending'), {
        userId: 'alice',
        displayName: 'Alice',
        text: 'Testimonio pendiente de Alice.',
        missionId: null,
        status: 'pending',
        createdAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'audit_logs/log1'), {
        action: 'setUserRole',
        actorUid: 'admin1',
        createdAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'deletion_requests/alice'), {
        uid: 'alice',
        requestedAt: FIXED_CREATED_AT,
      }),
      setDoc(doc(fs, 'recovery_codes/alice'), { codeHash: 'x', expiresAt: FIXED_CREATED_AT }),
    ];
    await Promise.all(writes);
  });
}

before(async () => {
  testEnv = await createFirestoreEnv();
  ctx = buildContexts(testEnv);
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

// ---------------------------------------------------------------------------
describe('sin autenticación', () => {
  test('no puede leer user_passport', async () => {
    await assertFails(getDoc(doc(db('unauth'), 'user_passport/alice')));
  });

  test('no puede buscar user_passport por username (la búsqueda previa al login queda cerrada)', async () => {
    await assertFails(
      getDocs(query(collection(db('unauth'), 'user_passport'), where('username', '==', 'alice'))),
    );
  });

  test('no puede leer stamp', async () => {
    await assertFails(getDoc(doc(db('unauth'), 'stamp/m1')));
  });

  test('no puede leer sermons', async () => {
    await assertFails(getDoc(doc(db('unauth'), 'sermons/sActive')));
  });

  test('no puede leer public_profiles', async () => {
    await assertFails(getDoc(doc(db('unauth'), 'public_profiles/alice')));
  });

  test('no puede leer cell', async () => {
    await assertFails(getDoc(doc(db('unauth'), 'cell/cell1')));
  });

  test('no puede crear testimonios', async () => {
    await assertFails(addDoc(collection(db('unauth'), 'testimonials'), newTestimonial('alice')));
  });
});

// ---------------------------------------------------------------------------
describe('user_passport: creación', () => {
  test('el usuario puede crear su propio pasaporte válido', async () => {
    await assertSucceeds(setDoc(doc(db('carol'), 'user_passport/carol'), newPassport('carol')));
  });

  test('puede crear el pasaporte mínimo (solo campos obligatorios)', async () => {
    await assertSucceeds(
      setDoc(doc(db('carol'), 'user_passport/carol'), {
        id: 'carol',
        username: 'carol',
        passportNumber: 'PM-2026-CARO',
        fullName: 'Carol',
        nationality: 'El Salvador',
        cellId: '',
      }),
    );
  });

  test('acepta dateOfBirth como Timestamp', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { dateOfBirth: Timestamp.fromDate(new Date('2001-05-01T06:00:00Z')) }),
      ),
    );
  });

  const forbiddenOnCreate = {
    isAdmin: true,
    canShowQR: true,
    role: 'admin',
    stampCount: 99,
    roleVersion: 5,
    lastRedemptionAt: Timestamp.now(),
    deletionRequestedAt: Timestamp.now(),
  };
  for (const [field, value] of Object.entries(forbiddenOnCreate)) {
    test(`no puede crear el pasaporte con ${field}`, async () => {
      await assertFails(
        setDoc(doc(db('carol'), 'user_passport/carol'), newPassport('carol', { [field]: value })),
      );
    });
  }

  test('no puede crear el pasaporte con stamps no vacío', async () => {
    await assertFails(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { stamps: [{ stampId: 'm1', dateObtained: Timestamp.now() }] }),
      ),
    );
  });

  test('no puede crear el pasaporte con el username de otra persona', async () => {
    await assertFails(
      setDoc(doc(db('carol'), 'user_passport/carol'), newPassport('carol', { username: 'alice' })),
    );
  });

  test('no puede crear el pasaporte con un id distinto a su uid', async () => {
    await assertFails(
      setDoc(doc(db('carol'), 'user_passport/carol'), newPassport('carol', { id: 'alice' })),
    );
  });

  test('no puede crear el pasaporte de otro usuario', async () => {
    await assertFails(
      setDoc(doc(db('carol'), 'user_passport/zed'), newPassport('zed', { username: 'carol' })),
    );
  });

  test('no puede crear el pasaporte sin campos obligatorios', async () => {
    const { nationality, ...withoutNationality } = newPassport('carol');
    await assertFails(setDoc(doc(db('carol'), 'user_passport/carol'), withoutNationality));
  });

  test('no puede crear el pasaporte con fullName de más de 80 caracteres', async () => {
    await assertFails(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { fullName: 'x'.repeat(81) }),
      ),
    );
  });

  test('no puede crear el pasaporte con createdAt distinto de la hora del servidor', async () => {
    await assertFails(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { createdAt: Timestamp.fromDate(new Date('2020-01-01')) }),
      ),
    );
  });

  test('no puede crear el pasaporte con claves desconocidas en notificationPrefs', async () => {
    await assertFails(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { notificationPrefs: { ...ALL_PREFS, marketing: true } }),
      ),
    );
  });

  test('no puede crear el pasaporte con passportNumber fuera de formato', async () => {
    await assertFails(
      setDoc(
        doc(db('carol'), 'user_passport/carol'),
        newPassport('carol', { passportNumber: 'ADMIN' }),
      ),
    );
  });
});

// ---------------------------------------------------------------------------
describe('user_passport: actualización', () => {
  const escalation = {
    role: 'admin',
    isAdmin: true,
    canShowQR: true,
    stamps: [{ stampId: 'm1', dateObtained: Timestamp.now() }],
    stampCount: 50,
    roleVersion: 99,
    lastRedemptionAt: Timestamp.now(),
    deletionRequestedAt: Timestamp.now(),
  };
  for (const [field, value] of Object.entries(escalation)) {
    test(`el usuario no puede modificar su propio ${field} (escalada de privilegios)`, async () => {
      await assertFails(
        updateDoc(doc(db('alice'), 'user_passport/alice'), {
          [field]: value,
          updatedAt: serverTimestamp(),
        }),
      );
    });
  }

  test('el usuario no puede borrar su campo role', async () => {
    await assertFails(updateDoc(doc(db('alice'), 'user_passport/alice'), { role: deleteField() }));
  });

  test('el usuario no puede cambiar username ni passportNumber', async () => {
    await assertFails(updateDoc(doc(db('alice'), 'user_passport/alice'), { username: 'root' }));
    await assertFails(
      updateDoc(doc(db('alice'), 'user_passport/alice'), { passportNumber: 'PM-2026-ROOT' }),
    );
  });

  test('el usuario puede actualizar fullName, cellId, communityVisible y notificationPrefs', async () => {
    await assertSucceeds(
      updateDoc(doc(db('alice'), 'user_passport/alice'), {
        fullName: 'Alice Nueva',
        cellId: 'cell2',
        communityVisible: false,
        notificationPrefs: { newMission: false, missionReminder: true, newSermon: false, stampConfirmed: true },
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el usuario puede actualizar nationality, showNationality y showCell', async () => {
    await assertSucceeds(
      updateDoc(doc(db('alice'), 'user_passport/alice'), {
        nationality: 'Guatemala',
        showNationality: true,
        showCell: false,
      }),
    );
  });

  test('el usuario no puede dejar fullName vacío', async () => {
    await assertFails(updateDoc(doc(db('alice'), 'user_passport/alice'), { fullName: '' }));
  });

  test('el usuario no puede poner tipos inválidos en communityVisible', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'user_passport/alice'), { communityVisible: 'yes' }),
    );
  });

  test('updatedAt debe ser la hora del servidor', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'user_passport/alice'), {
        fullName: 'Alice',
        updatedAt: Timestamp.fromDate(new Date('2020-01-01')),
      }),
    );
  });

  test('el usuario no puede borrar su pasaporte', async () => {
    await assertFails(deleteDoc(doc(db('alice'), 'user_passport/alice')));
  });

  test('el admin tampoco puede escribir role/isAdmin/stamps desde el cliente', async () => {
    await assertFails(updateDoc(doc(db('admin'), 'user_passport/bob'), { role: 'qrPresenter' }));
    await assertFails(updateDoc(doc(db('admin'), 'user_passport/bob'), { isAdmin: true }));
    await assertFails(updateDoc(doc(db('admin'), 'user_passport/bob'), { canShowQR: true }));
    await assertFails(updateDoc(doc(db('admin'), 'user_passport/bob'), { stamps: [{ stampId: 'm1' }] }));
  });
});

// ---------------------------------------------------------------------------
describe('user_passport: privacidad entre usuarios', () => {
  test('el usuario puede leer su propio pasaporte', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'user_passport/alice')));
  });

  test('el usuario no puede leer el pasaporte (perfil privado) de otro', async () => {
    await assertFails(getDoc(doc(db('alice'), 'user_passport/bob')));
  });

  test('el usuario no puede listar todos los pasaportes', async () => {
    await assertFails(getDocs(collection(db('alice'), 'user_passport')));
  });

  test('el usuario no puede escribir el pasaporte de otro', async () => {
    await assertFails(updateDoc(doc(db('alice'), 'user_passport/bob'), { fullName: 'Hackeado' }));
  });

  test('el presentador no puede leer pasaportes ajenos', async () => {
    await assertFails(getDoc(doc(db('presenter'), 'user_passport/bob')));
  });

  test('el admin puede leer el pasaporte de otros', async () => {
    await assertSucceeds(getDoc(doc(db('admin'), 'user_passport/bob')));
  });

  test('el admin puede listar pasaportes', async () => {
    await assertSucceeds(getDocs(collection(db('admin'), 'user_passport')));
  });
});

// ---------------------------------------------------------------------------
describe('user_passport/{uid}/redemptions', () => {
  test('el usuario no puede falsificar un canje en su propia ruta', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/redemptions/m2'), {
        missionId: 'm2',
        userId: 'alice',
        missionName: 'Misión falsa',
        status: 'confirmed',
        source: 'qr',
        redeemedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('el usuario no puede modificar ni borrar un canje existente', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'user_passport/alice/redemptions/m1'), { source: 'legacy_migration' }),
    );
    await assertFails(deleteDoc(doc(db('alice'), 'user_passport/alice/redemptions/m1')));
  });

  test('el presentador no puede escribir canjes', async () => {
    await assertFails(
      setDoc(doc(db('presenter'), 'user_passport/alice/redemptions/m2'), {
        missionId: 'm2',
        userId: 'alice',
        status: 'confirmed',
        source: 'qr',
      }),
    );
  });

  test('el admin no puede escribir canjes desde el cliente', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'user_passport/bob/redemptions/m2'), {
        missionId: 'm2',
        userId: 'bob',
        status: 'confirmed',
        source: 'qr',
      }),
    );
  });

  test('el usuario puede leer sus propios canjes', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'user_passport/alice/redemptions/m1')));
    await assertSucceeds(getDocs(collection(db('alice'), 'user_passport/alice/redemptions')));
  });

  test('el usuario no puede leer los canjes de otro', async () => {
    await assertFails(getDoc(doc(db('alice'), 'user_passport/bob/redemptions/m1')));
    await assertFails(getDocs(collection(db('alice'), 'user_passport/bob/redemptions')));
  });

  test('el admin puede leer los canjes de otros', async () => {
    await assertSucceeds(getDocs(collection(db('admin'), 'user_passport/bob/redemptions')));
  });
});

// ---------------------------------------------------------------------------
describe('public_profiles', () => {
  test('el usuario puede leer un perfil visible', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'public_profiles/dave')));
  });

  test('el usuario no puede leer un perfil oculto (communityVisible false)', async () => {
    await assertFails(getDoc(doc(db('alice'), 'public_profiles/bob')));
  });

  test('el dueño puede leer su propio perfil aunque esté oculto', async () => {
    await assertSucceeds(getDoc(doc(db('bob'), 'public_profiles/bob')));
  });

  test('el admin puede leer un perfil oculto', async () => {
    await assertSucceeds(getDoc(doc(db('admin'), 'public_profiles/bob')));
  });

  test("el usuario puede listar con where('communityVisible', '==', true)", async () => {
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db('alice'), 'public_profiles'),
          where('communityVisible', '==', true),
          orderBy('displayName'),
        ),
      ),
    );
    const ids = snap.docs.map((d) => d.id).sort();
    if (ids.join(',') !== 'alice,dave') throw new Error(`perfiles inesperados: ${ids}`);
  });

  test('el usuario no puede listar sin filtro', async () => {
    await assertFails(getDocs(collection(db('alice'), 'public_profiles')));
  });

  test('el usuario no puede escribir su propio perfil público', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'public_profiles/alice'), { stampCount: 100 }),
    );
    await assertFails(
      setDoc(doc(db('carol'), 'public_profiles/carol'), {
        uid: 'carol',
        displayName: 'Carol',
        communityVisible: true,
      }),
    );
  });

  test('el admin no puede escribir perfiles públicos desde el cliente', async () => {
    await assertFails(updateDoc(doc(db('admin'), 'public_profiles/bob'), { communityVisible: true }));
  });
});

// ---------------------------------------------------------------------------
describe('stamp (catálogo de misiones)', () => {
  for (const who of ['alice', 'presenter', 'admin']) {
    test(`${who} puede leer el catálogo`, async () => {
      await assertSucceeds(getDoc(doc(db(who), 'stamp/m1')));
      await assertSucceeds(getDocs(collection(db(who), 'stamp')));
    });
  }

  test('el usuario no puede crear sellos', async () => {
    await assertFails(
      addDoc(collection(db('alice'), 'stamp'), { name: 'Falsa', isoCode: 'XX', active: true }),
    );
  });

  test('el presentador no puede crear sellos', async () => {
    await assertFails(
      addDoc(collection(db('presenter'), 'stamp'), { name: 'Falsa', isoCode: 'XX', active: true }),
    );
  });

  test('el presentador no puede editar sellos', async () => {
    await assertFails(updateDoc(doc(db('presenter'), 'stamp/m1'), { active: false }));
  });

  test('el admin no puede escribir sellos desde el cliente (solo Cloud Functions)', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'stamp/m2'), { name: 'Nueva', isoCode: 'HN', active: true }),
    );
    await assertFails(updateDoc(doc(db('admin'), 'stamp/m1'), { active: false }));
    await assertFails(deleteDoc(doc(db('admin'), 'stamp/m1')));
  });
});

describe('cell', () => {
  test('el usuario autenticado puede leer células', async () => {
    await assertSucceeds(getDocs(collection(db('alice'), 'cell')));
  });

  test('nadie escribe células desde el cliente', async () => {
    await assertFails(setDoc(doc(db('admin'), 'cell/cell2'), { name: 'Nueva' }));
    await assertFails(updateDoc(doc(db('alice'), 'cell/cell1'), { name: 'X' }));
  });
});

// ---------------------------------------------------------------------------
describe('sermons', () => {
  test('el usuario puede leer una prédica activa', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'sermons/sActive')));
  });

  test('el usuario no puede leer una prédica inactiva', async () => {
    await assertFails(getDoc(doc(db('alice'), 'sermons/sInactive')));
  });

  test("el usuario puede consultar where('active', '==', true) ordenado por publishedAt", async () => {
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db('alice'), 'sermons'),
          where('active', '==', true),
          orderBy('publishedAt', 'desc'),
        ),
      ),
    );
    if (snap.size !== 1) throw new Error(`se esperaba 1 prédica activa, hay ${snap.size}`);
  });

  test('el usuario no puede consultar prédicas sin filtrar por active', async () => {
    await assertFails(getDocs(collection(db('alice'), 'sermons')));
  });

  test('el admin puede leer prédicas inactivas y listar todas', async () => {
    await assertSucceeds(getDoc(doc(db('admin'), 'sermons/sInactive')));
    await assertSucceeds(getDocs(collection(db('admin'), 'sermons')));
  });

  for (const who of ['alice', 'presenter']) {
    test(`${who} no puede crear prédicas`, async () => {
      await assertFails(setDoc(doc(db(who), 'sermons/sNew'), newSermon(who === 'alice' ? 'alice' : 'presenter1')));
    });

    test(`${who} no puede editar prédicas`, async () => {
      await assertFails(
        updateDoc(doc(db(who), 'sermons/sActive'), { title: 'Cambiado', updatedAt: serverTimestamp() }),
      );
    });

    test(`${who} no puede borrar prédicas`, async () => {
      await assertFails(deleteDoc(doc(db(who), 'sermons/sActive')));
    });
  }

  test('el admin puede crear una prédica válida', async () => {
    await assertSucceeds(setDoc(doc(db('admin'), 'sermons/sNew'), newSermon()));
  });

  test('el admin puede crear una prédica con portada en sermon_covers/{id}/', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('admin'), 'sermons/sNew'),
        newSermon('admin1', {
          coverImageUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/sermon_covers%2FsNew%2Fcover.jpg',
          coverStoragePath: 'sermon_covers/sNew/cover.jpg',
          platform: 'other',
          domain: 'example.org',
          externalVideoId: null,
        }),
      ),
    );
  });

  test('el admin puede crear una prédica sin campos opcionales (sortOrder, deletedAt...)', async () => {
    const { sortOrder, deletedAt, coverStoragePath, externalVideoId, ...minimal } = newSermon();
    await assertSucceeds(setDoc(doc(db('admin'), 'sermons/sNew'), minimal));
  });

  test('el admin no puede crear una prédica con sourceUrl http:', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { sourceUrl: 'http://youtube.com/watch?v=1' })),
    );
  });

  test('el admin no puede crear una prédica con sourceUrl javascript:', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { sourceUrl: 'javascript:alert(1)' })),
    );
  });

  test('el admin no puede crear una prédica con sourceUrl de más de 2048 caracteres', async () => {
    await assertFails(
      setDoc(
        doc(db('admin'), 'sermons/sNew'),
        newSermon('admin1', { sourceUrl: `https://example.org/${'a'.repeat(2048)}` }),
      ),
    );
  });

  test('el admin no puede crear una prédica con campos desconocidos', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { isFeatured: true })),
    );
  });

  test('el admin no puede crear una prédica con título de más de 200 caracteres', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { title: 't'.repeat(201) })),
    );
  });

  test('el admin no puede crear una prédica con título vacío', async () => {
    await assertFails(setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { title: '' })));
  });

  test('el admin no puede crear una prédica con createdBy de otra persona', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { createdBy: 'someoneElse' })),
    );
  });

  test('el admin no puede crear una prédica con announcedAt (solo servidor)', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { announcedAt: serverTimestamp() })),
    );
  });

  test('el admin no puede crear una prédica con plataforma desconocida', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { platform: 'tiktok' })),
    );
  });

  test('el admin no puede crear una prédica con coverImageUrl no https', async () => {
    await assertFails(
      setDoc(
        doc(db('admin'), 'sermons/sNew'),
        newSermon('admin1', { coverImageUrl: 'data:image/png;base64,AAAA' }),
      ),
    );
  });

  test('el admin no puede apuntar coverStoragePath a otra prédica o carpeta', async () => {
    await assertFails(
      setDoc(
        doc(db('admin'), 'sermons/sNew'),
        newSermon('admin1', { coverStoragePath: 'sermon_covers/otra/cover.jpg' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(db('admin'), 'sermons/sNew'),
        newSermon('admin1', { coverStoragePath: 'mission_images/sNew/cover.jpg' }),
      ),
    );
  });

  test('el admin no puede crear una prédica borrada y activa a la vez', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { deleted: true, active: true })),
    );
  });

  test('el admin no puede crear con createdAt distinto de la hora del servidor', async () => {
    await assertFails(
      setDoc(doc(db('admin'), 'sermons/sNew'), newSermon('admin1', { createdAt: FIXED_CREATED_AT })),
    );
  });

  test('el update del admin que conserva createdAt y un announcedAt existente pasa', async () => {
    await assertSucceeds(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        title: 'La gran comisión (editado)',
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin puede hacer borrado lógico (deleted true, active false)', async () => {
    await assertSucceeds(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        active: false,
        deleted: true,
        deletedAt: serverTimestamp(),
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin no puede modificar ni quitar announcedAt', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        announcedAt: serverTimestamp(),
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        announcedAt: deleteField(),
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin no puede añadir announcedAt a una prédica que no lo tiene', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sInactive'), {
        announcedAt: serverTimestamp(),
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin no puede cambiar createdAt ni createdBy al editar', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        createdAt: serverTimestamp(),
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        createdBy: 'otro',
        updatedBy: 'admin1',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin debe firmar updatedBy/updatedAt al editar', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), { title: 'Sin firma' }),
    );
    await assertFails(
      updateDoc(doc(db('admin'), 'sermons/sActive'), {
        title: 'Firma ajena',
        updatedBy: 'otro',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin puede borrar definitivamente una prédica', async () => {
    await assertSucceeds(deleteDoc(doc(db('admin'), 'sermons/sInactive')));
  });
});

// ---------------------------------------------------------------------------
describe('user_passport/{uid}/journal', () => {
  test('el dueño puede crear, leer, actualizar y borrar entradas', async () => {
    const ref = doc(db('alice'), 'user_passport/alice/journal/j2');
    await assertSucceeds(
      setDoc(ref, {
        text: 'Hoy oramos por la comunidad.',
        missionId: null,
        missionName: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(
      getDocs(collection(db('alice'), 'user_passport/alice/journal')),
    );
    await assertSucceeds(
      updateDoc(ref, { text: 'Hoy oramos y servimos.', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test('otro usuario no puede leer ni escribir el diario ajeno', async () => {
    await assertFails(getDoc(doc(db('bob'), 'user_passport/alice/journal/j1')));
    await assertFails(getDocs(collection(db('bob'), 'user_passport/alice/journal')));
    await assertFails(
      setDoc(doc(db('bob'), 'user_passport/alice/journal/j3'), {
        text: 'Intruso',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(db('bob'), 'user_passport/alice/journal/j1')));
  });

  test('el admin tampoco lee diarios ajenos', async () => {
    await assertFails(getDoc(doc(db('admin'), 'user_passport/alice/journal/j1')));
  });

  test('texto de más de 5000 caracteres es rechazado', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/journal/j2'), {
        text: 'a'.repeat(5001),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('texto vacío y campos desconocidos son rechazados', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/journal/j2'), {
        text: '',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/journal/j2'), {
        text: 'Hola',
        mood: 'feliz',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('no se puede cambiar createdAt al actualizar', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'user_passport/alice/journal/j1'), {
        text: 'Editado',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
describe('user_passport/{uid}/fcm_tokens', () => {
  test('el dueño puede registrar, leer y borrar su token', async () => {
    const ref = doc(db('alice'), 'user_passport/alice/fcm_tokens/tokenAlice2');
    await assertSucceeds(
      setDoc(ref, { token: 'tokenAlice2', platform: 'web', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(
      setDoc(ref, { token: 'tokenAlice2', platform: 'web', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test('otro usuario no puede leer, escribir ni borrar tokens ajenos', async () => {
    await assertFails(getDoc(doc(db('bob'), 'user_passport/alice/fcm_tokens/tokenAlice1')));
    await assertFails(
      setDoc(doc(db('bob'), 'user_passport/alice/fcm_tokens/tokenBob'), {
        token: 'tokenBob',
        platform: 'android',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(db('bob'), 'user_passport/alice/fcm_tokens/tokenAlice1')));
  });

  test('el token debe coincidir con el id y la plataforma ser válida', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/fcm_tokens/tokenA'), {
        token: 'tokenB',
        platform: 'android',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/fcm_tokens/tokenA'), {
        token: 'tokenA',
        platform: 'windows',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'user_passport/alice/fcm_tokens/tokenA'), {
        token: 'tokenA',
        platform: 'ios',
        updatedAt: FIXED_CREATED_AT,
      }),
    );
  });
});

// ---------------------------------------------------------------------------
describe('testimonials', () => {
  test('el usuario puede crear un testimonio pendiente', async () => {
    await assertSucceeds(addDoc(collection(db('alice'), 'testimonials'), newTestimonial('alice')));
  });

  test('el usuario no puede crear un testimonio ya aprobado', async () => {
    await assertFails(
      addDoc(collection(db('alice'), 'testimonials'), newTestimonial('alice', { status: 'approved' })),
    );
  });

  test('el usuario no puede crear un testimonio a nombre de otro', async () => {
    await assertFails(
      addDoc(collection(db('alice'), 'testimonials'), newTestimonial('bob')),
    );
  });

  test('texto de menos de 10 o más de 1000 caracteres es rechazado', async () => {
    await assertFails(
      addDoc(collection(db('alice'), 'testimonials'), newTestimonial('alice', { text: 'corto' })),
    );
    await assertFails(
      addDoc(
        collection(db('alice'), 'testimonials'),
        newTestimonial('alice', { text: 'x'.repeat(1001) }),
      ),
    );
  });

  test('no se puede crear con moderatedBy ni campos extra', async () => {
    await assertFails(
      addDoc(
        collection(db('alice'), 'testimonials'),
        newTestimonial('alice', { moderatedBy: 'alice' }),
      ),
    );
  });

  test('el usuario no puede leer el testimonio pendiente de otro', async () => {
    await assertFails(getDoc(doc(db('alice'), 'testimonials/tBobPending')));
  });

  test('el usuario puede leer un testimonio aprobado', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'testimonials/tBobApproved')));
  });

  test('el autor puede leer su testimonio pendiente', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'testimonials/tAlicePending')));
  });

  test('consultas permitidas: aprobados y los propios', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(db('alice'), 'testimonials'),
          where('status', '==', 'approved'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(db('alice'), 'testimonials'),
          where('userId', '==', 'alice'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertFails(getDocs(collection(db('alice'), 'testimonials')));
  });

  test('el admin puede aprobar un testimonio', async () => {
    await assertSucceeds(
      updateDoc(doc(db('admin'), 'testimonials/tBobPending'), {
        status: 'approved',
        moderatedBy: 'admin1',
        moderatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin no puede cambiar el texto al moderar', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'testimonials/tBobPending'), {
        status: 'approved',
        text: 'Texto reescrito por el admin',
        moderatedBy: 'admin1',
        moderatedAt: serverTimestamp(),
      }),
    );
  });

  test('el admin debe firmar moderatedBy con su uid', async () => {
    await assertFails(
      updateDoc(doc(db('admin'), 'testimonials/tBobPending'), {
        status: 'rejected',
        moderatedBy: 'otro',
        moderatedAt: serverTimestamp(),
      }),
    );
  });

  test('el usuario no puede aprobar testimonios (ni el suyo)', async () => {
    await assertFails(
      updateDoc(doc(db('alice'), 'testimonials/tAlicePending'), {
        status: 'approved',
        moderatedBy: 'alice',
        moderatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db('alice'), 'testimonials/tBobPending'), {
        status: 'approved',
        moderatedBy: 'alice',
        moderatedAt: serverTimestamp(),
      }),
    );
  });

  test('el autor puede borrar su testimonio', async () => {
    await assertSucceeds(deleteDoc(doc(db('alice'), 'testimonials/tAlicePending')));
  });

  test('otro usuario no puede borrar un testimonio ajeno; el admin sí', async () => {
    await assertFails(deleteDoc(doc(db('alice'), 'testimonials/tBobApproved')));
    await assertSucceeds(deleteDoc(doc(db('admin'), 'testimonials/tBobApproved')));
  });
});

// ---------------------------------------------------------------------------
describe('colecciones solo-servidor', () => {
  test('el admin puede leer audit_logs', async () => {
    await assertSucceeds(getDoc(doc(db('admin'), 'audit_logs/log1')));
    await assertSucceeds(getDocs(collection(db('admin'), 'audit_logs')));
  });

  test('el usuario no puede leer audit_logs', async () => {
    await assertFails(getDoc(doc(db('alice'), 'audit_logs/log1')));
  });

  test('el admin no puede escribir audit_logs', async () => {
    await assertFails(setDoc(doc(db('admin'), 'audit_logs/log2'), { action: 'fake' }));
    await assertFails(deleteDoc(doc(db('admin'), 'audit_logs/log1')));
  });

  test('deletion_requests: el dueño lee la suya, otro no, nadie escribe', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'deletion_requests/alice')));
    await assertFails(getDoc(doc(db('bob'), 'deletion_requests/alice')));
    await assertSucceeds(getDoc(doc(db('admin'), 'deletion_requests/alice')));
    await assertFails(setDoc(doc(db('bob'), 'deletion_requests/bob'), { uid: 'bob' }));
  });

  for (const path of ['recovery_codes/alice', 'notification_log/k1', '_migrations/run1', 'rate_limits/alice']) {
    test(`${path.split('/')[0]}: sin acceso de cliente (ni admin)`, async () => {
      await assertFails(getDoc(doc(db('admin'), path)));
      await assertFails(getDoc(doc(db('alice'), path)));
      await assertFails(setDoc(doc(db('admin'), path), { x: 1 }));
    });
  }

  test('una colección no declarada queda denegada', async () => {
    await assertFails(getDoc(doc(db('admin'), 'whatever/x')));
    await assertFails(setDoc(doc(db('admin'), 'whatever/x'), { x: 1 }));
    await assertFails(setDoc(doc(db('alice'), 'user_passport/alice/other/x'), { x: 1 }));
  });
});
