# Pruebas de Firebase (reglas e integración)

Pruebas automáticas de las reglas de seguridad (`firestore.rules`, `storage.rules`) y del flujo
de Cloud Functions, ejecutadas **solo contra los emuladores locales**. El contrato que verifican
está en [`docs/ARQUITECTURA.md`](../../docs/ARQUITECTURA.md).

Todas las ejecuciones usan el proyecto `demo-pasaporte-test`: el prefijo `demo-` garantiza que
los emuladores nunca contacten el proyecto de producción (`pasaportemisionerovirtual`).

## Requisitos

- Node.js 22 o superior (probado con Node 24).
- Java 11 o superior (los emuladores de Firestore y Storage son JAR; probado con Java 25).
- Firebase CLI (`npm install -g firebase-tools`, probado con 15.22). La primera ejecución
  descarga los JAR de los emuladores en `~/.cache/firebase/emulators`.

```bash
cd tests/firebase
npm install
```

## 1. Reglas de seguridad

```bash
npm run test:rules
```

Levanta los emuladores de Firestore y Storage, carga las reglas del repositorio y ejecuta
`rules/*.test.mjs` con el ejecutor nativo de Node (`node:test`).

| Archivo | Qué prueba |
|---|---|
| `rules/firestore.test.mjs` | `user_passport` (creación, escalada de privilegios, privacidad), `redemptions`, `journal`, `fcm_tokens`, `public_profiles`, `stamp`, `cell`, `sermons`, `testimonials` y colecciones solo-servidor. |
| `rules/storage.test.mjs` | `sermon_covers/` y `mission_images/`: solo admin sube imágenes JPEG/PNG/WebP < 5 MB; los autenticados leen; todo lo demás se deniega. |
| `rules/_helpers.mjs` | Entorno de pruebas y contextos (sin sesión, usuario `alice`, presentador `role: qrPresenter`, admin `role: admin`). |

## 2. Integración de punta a punta

```bash
npm run test:integration
```

`pretest:integration` compila las funciones (`npm --prefix ../../functions run build`); después se
levantan los emuladores de Auth, Firestore y Functions y se ejecuta `integration/flow.test.mjs`:

1. Siembra con `firebase-admin` un admin, un presentador y un usuario (claims + `user_passport`).
2. El admin crea una misión activa (`saveMission`), el presentador emite el QR (`issueQrToken`)
   y el usuario lo canjea (`redeemStamp` → `confirmed`, luego `alreadyRedeemed`; firma alterada →
   `invalid`). Verifica `user_passport/{uid}/redemptions/{missionId}` (`source: 'qr'`,
   `validatedBy` = presentador).
3. Permisos: usuario → `issueQrToken`, presentador → `saveMission`, usuario → `setUserRole`
   devuelven `permission-denied`; el admin asigna `qrPresenter` y el claim aparece en Auth.
4. Migración heredada (`runMigrations`, HTTP con `Authorization: Bearer <MIGRATION_TOKEN>`):
   `dryRun: true` no escribe; `dryRun: false` crea el canje `legacy_migration` y el claim;
   una segunda ejecución no escribe nada (idempotente).

Necesita `functions/.secret.local` con valores ficticios, por ejemplo:

```
QR_SIGNING_SECRET=secreto-de-prueba-de-al-menos-32-caracteres
MIGRATION_TOKEN=token-de-migracion-de-prueba
PLACES_API_KEY=dummy
```

(`*.local` está excluido del despliegue en `firebase.json`; no lo subas al repositorio.)

## Todo junto

```bash
npm test
```

## Cómo funcionan los scripts

`scripts/emulators-exec.mjs` equivale a:

```bash
firebase emulators:exec --only <emuladores> --project demo-pasaporte-test \
  --config ../../firebase.json "<comando>"
```

y además:

- define `FUNCTIONS_DISCOVERY_TIMEOUT=60` (si no existe): la CLI solo espera 10 s para cargar las
  funciones y, en un arranque en frío, las pruebas podrían empezar sin funciones cargadas;
- antepone `$JAVA_HOME/bin` al `PATH`. En Windows, el instalador de Oracle pone primero en el
  `PATH` un lanzador (`C:\Program Files\Common Files\Oracle\Java\javapath\java.exe`); al apagar,
  la CLI de Firebase solo cierra ese lanzador y la JVM del emulador de Firestore queda huérfana en
  el puerto 8080, así que la siguiente ejecución falla con *port taken*. Si eso ocurre (por ejemplo
  al usar el comando de arriba directamente), cierra el proceso `java.exe` que escucha en el
  puerto 8080 o define `JAVA_HOME` apuntando al JDK.

### Ejecutar contra emuladores ya levantados

Para iterar rápido sobre las reglas:

```bash
# Terminal 1 (raíz del repo)
firebase emulators:start --only firestore,storage --project demo-pasaporte-test
# Terminal 2 (tests/firebase)
node --test --test-concurrency=1 "rules/*.test.mjs"
```

Las pruebas recargan las reglas desde los archivos del repositorio en cada ejecución. Si las
variables `FIRESTORE_EMULATOR_HOST` / `FIREBASE_STORAGE_EMULATOR_HOST` no están definidas se usan
los puertos de `firebase.json` (8080 y 9199).

## Notas

- Nada de esto despliega ni toca producción. No ejecutes `firebase deploy` desde aquí.
- `--test-concurrency=1` evita que dos archivos limpien el mismo emulador a la vez.
