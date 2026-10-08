// Pruebas de storage.rules contra el emulador de Storage.
// Contrato: docs/ARQUITECTURA.md (sección 4).
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteObject, getMetadata, listAll, ref, uploadBytes } from 'firebase/storage';
import { buildContexts, createStorageEnv } from './_helpers.mjs';

let testEnv;
let ctx;

const storage = (name) => ctx[name].storage();

const MB = 1024 * 1024;
// Cabecera JPEG mínima seguida de relleno; el contenido real no importa a las reglas.
const smallJpeg = () => {
  const bytes = new Uint8Array(2048);
  bytes.set([0xff, 0xd8, 0xff, 0xe0]);
  return bytes;
};
const JPEG = { contentType: 'image/jpeg' };

function upload(who, path, bytes = smallJpeg(), metadata = JPEG) {
  return uploadBytes(ref(storage(who), path), bytes, metadata);
}

before(async () => {
  testEnv = await createStorageEnv();
  ctx = buildContexts(testEnv);
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    const s = admin.storage();
    await uploadBytes(ref(s, 'sermon_covers/s1/cover.jpg'), smallJpeg(), JPEG);
    await uploadBytes(ref(s, 'mission_images/m1/photo.png'), smallJpeg(), { contentType: 'image/png' });
    await uploadBytes(ref(s, 'mission_service_photos/m1/culto_1.jpg'), smallJpeg(), JPEG);
  });
});

describe('Storage: escritura', () => {
  test('sin autenticación no se puede subir', async () => {
    await assertFails(upload('unauth', 'sermon_covers/s1/new.jpg'));
  });

  test('un usuario normal no puede subir a sermon_covers', async () => {
    await assertFails(upload('alice', 'sermon_covers/s1/new.jpg'));
  });

  test('un usuario normal no puede subir a mission_images', async () => {
    await assertFails(upload('alice', 'mission_images/m1/new.jpg'));
  });

  test('el presentador no puede subir', async () => {
    await assertFails(upload('presenter', 'sermon_covers/s1/new.jpg'));
    await assertFails(upload('presenter', 'mission_images/m1/new.jpg'));
  });

  test('el admin puede subir image/jpeg de menos de 5 MB a sermon_covers', async () => {
    await assertSucceeds(upload('admin', 'sermon_covers/s2/cover.jpg'));
  });

  test('el admin puede subir image/png y image/webp a mission_images', async () => {
    await assertSucceeds(
      upload('admin', 'mission_images/m2/photo.png', smallJpeg(), { contentType: 'image/png' }),
    );
    await assertSucceeds(
      upload('admin', 'mission_images/m2/photo.webp', smallJpeg(), { contentType: 'image/webp' }),
    );
  });

  test('el admin puede reemplazar una portada existente', async () => {
    await assertSucceeds(upload('admin', 'sermon_covers/s1/cover.jpg'));
  });

  test('el admin no puede subir text/plain', async () => {
    await assertFails(
      upload('admin', 'sermon_covers/s2/notes.txt', new TextEncoder().encode('hola'), {
        contentType: 'text/plain',
      }),
    );
  });

  test('el admin no puede subir image/svg+xml ni image/gif', async () => {
    await assertFails(
      upload('admin', 'sermon_covers/s2/logo.svg', new TextEncoder().encode('<svg/>'), {
        contentType: 'image/svg+xml',
      }),
    );
    await assertFails(
      upload('admin', 'sermon_covers/s2/anim.gif', smallJpeg(), { contentType: 'image/gif' }),
    );
  });

  test('el admin no puede subir archivos de 5 MB o más', async () => {
    await assertFails(upload('admin', 'sermon_covers/s2/big.jpg', new Uint8Array(5 * MB + 1)));
    await assertFails(upload('admin', 'sermon_covers/s2/exact.jpg', new Uint8Array(5 * MB)));
  });

  test('el admin no puede subir fuera de las rutas permitidas', async () => {
    await assertFails(upload('admin', 'other/file.jpg'));
    await assertFails(upload('admin', 'user_uploads/alice/avatar.jpg'));
    await assertFails(upload('admin', 'sermon_covers/cover.jpg'));
    await assertFails(upload('admin', 'sermon_covers/s2/nested/cover.jpg'));
    await assertFails(upload('admin', 'cover.jpg'));
  });

  test('el admin no puede usar nombres de archivo inseguros', async () => {
    await assertFails(upload('admin', 'sermon_covers/s2/mi portada.jpg'));
    await assertFails(upload('admin', `sermon_covers/s2/${'a'.repeat(101)}.jpg`));
    await assertFails(upload('admin', 'sermon_covers/s2/..'));
  });
});

describe('Storage: lectura y borrado', () => {
  test('un usuario autenticado puede leer una portada', async () => {
    await assertSucceeds(getMetadata(ref(storage('alice'), 'sermon_covers/s1/cover.jpg')));
  });

  test('un usuario autenticado puede leer una imagen de misión', async () => {
    await assertSucceeds(getMetadata(ref(storage('presenter'), 'mission_images/m1/photo.png')));
  });

  test('sin autenticación no se puede leer una portada', async () => {
    await assertFails(getMetadata(ref(storage('unauth'), 'sermon_covers/s1/cover.jpg')));
  });

  test('un usuario normal no puede borrar portadas; el admin sí', async () => {
    await assertFails(deleteObject(ref(storage('alice'), 'sermon_covers/s1/cover.jpg')));
    await assertSucceeds(deleteObject(ref(storage('admin'), 'sermon_covers/s1/cover.jpg')));
  });
});

describe('Storage: fotos del culto', () => {
  test('un usuario autenticado puede ver y listar las fotos del culto', async () => {
    await assertSucceeds(getMetadata(ref(storage('alice'), 'mission_service_photos/m1/culto_1.jpg')));
    await assertSucceeds(listAll(ref(storage('alice'), 'mission_service_photos/m1')));
  });

  test('sin autenticación no se pueden ver ni listar', async () => {
    await assertFails(getMetadata(ref(storage('unauth'), 'mission_service_photos/m1/culto_1.jpg')));
    await assertFails(listAll(ref(storage('unauth'), 'mission_service_photos/m1')));
  });

  test('solo el administrador sube fotos del culto', async () => {
    await assertFails(upload('alice', 'mission_service_photos/m1/culto_2.jpg'));
    await assertFails(upload('presenter', 'mission_service_photos/m1/culto_2.jpg'));
    await assertSucceeds(upload('admin', 'mission_service_photos/m1/culto_2.jpg'));
  });

  test('el original de alta calidad puede pesar hasta 25 MB', async () => {
    const big = new Uint8Array(12 * MB);
    big.set([0xff, 0xd8, 0xff, 0xe0]);
    await assertSucceeds(upload('admin', 'mission_service_photos/m1/culto_3.jpg', big));
    await assertFails(upload('admin', 'mission_service_photos/m1/culto_4.jpg', new Uint8Array(26 * MB)));
  });

  test('el administrador no puede subir algo que no sea imagen', async () => {
    await assertFails(
      upload('admin', 'mission_service_photos/m1/nota.txt', new Uint8Array(10), { contentType: 'text/plain' }),
    );
  });

  test('solo el administrador borra fotos del culto', async () => {
    await assertFails(deleteObject(ref(storage('alice'), 'mission_service_photos/m1/culto_1.jpg')));
    await assertSucceeds(deleteObject(ref(storage('admin'), 'mission_service_photos/m1/culto_1.jpg')));
  });
});
