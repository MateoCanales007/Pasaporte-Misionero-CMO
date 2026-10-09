// Asigna un rol a un usuario del EMULADOR de Auth (nunca a producción).
// Uso: node scripts/set-role-emulator.mjs <usuario> <admin|qrPresenter|user>
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
const [username, role] = process.argv.slice(2);
if (!username || !['admin', 'qrPresenter', 'user'].includes(role)) {
  console.error('Uso: node scripts/set-role-emulator.mjs <usuario> <admin|qrPresenter|user>');
  process.exit(1);
}

initializeApp({ projectId: 'demo-pasaporte-test' });
const auth = getAuth();
const user = await auth.getUserByEmail(`${username.toLowerCase()}@cmo.com`);
await auth.setCustomUserClaims(user.uid, role === 'user' ? {} : { role });
console.log(`Rol "${role}" asignado a ${username} (${user.uid}) en el emulador. Cierra y abre sesión en la app.`);
