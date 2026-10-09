# Cloud Functions — Pasaporte Misionero CMO

Backend del proyecto `pasaportemisionerovirtual` (región `us-central1`, Node 24,
firebase-functions v2). El contrato de datos y de API está en
[`docs/ARQUITECTURA.md`](../docs/ARQUITECTURA.md).

## Scripts

| Comando | Qué hace |
|---|---|
| `npm run build` | Limpia `lib/` y compila TypeScript. |
| `npm run lint` | ESLint (estilo Google). |
| `npm test` | Compila con `tsconfig.test.json` y ejecuta las pruebas unitarias (`node:test`). |
| `npm run serve` | Compila y levanta el emulador de Functions. |

## Estructura

```
src/
  index.ts        solo exportaciones
  setup.ts        initializeApp + setGlobalOptions
  config.ts       secretos, constantes, ENFORCE_APP_CHECK
  core/           auth, auditoría, validación, errores, utilidades puras
  qr/             token (HMAC), issueQrToken, redeemStamp (lógica pura + adaptador Firestore)
  missions/       horarios, validación, saveMission, setMissionStatus
  roles/          setUserRole
  profiles/       perfil público (puro) + trigger onUserPassportWritten
  notifications/  temas FCM, envíos, triggers y recordatorios
  sermons/        análisis de URL y oEmbed (solo YouTube y Vimeo)
  recovery/       códigos de recuperación
  account/        requestAccountDeletion
  places/         callables de Google Places
  migrations/     planificador puro + runMigrations (HTTP)
test/             pruebas unitarias (sin Firebase)
```

## Secretos (Secret Manager)

Nunca se guardan en el código. Configúralos una vez por proyecto:

```bash
firebase functions:secrets:set QR_SIGNING_SECRET   # 32+ caracteres aleatorios
firebase functions:secrets:set PLACES_API_KEY      # llave de servidor restringida a Places API
firebase functions:secrets:set MIGRATION_TOKEN     # 32+ caracteres aleatorios
```

Para generar valores aleatorios: `openssl rand -base64 48`.

`PLACES_API_KEY` debe ser una llave **distinta** de la llave cliente de Firebase,
restringida a la Places API.

## App Check

`ENFORCE_APP_CHECK` se lee de `functions/.env` (por defecto `false`). Cuando la app
envíe tokens de App Check, cámbialo a `true` (o crea `.env.pasaportemisionerovirtual`)
y vuelve a desplegar.

## Emulador

1. Copia `.secret.local.example` a `.secret.local` (ignorado por git) y usa valores
   de prueba.
2. Desde la raíz del repositorio:

   ```bash
   npm --prefix functions run build
   firebase emulators:start --only functions,firestore,auth
   ```

En el emulador **no** se envían notificaciones FCM ni se cambian suscripciones a
temas: solo se registran en el log.

## Migración (`runMigrations`)

Callable protegida con `MIGRATION_TOKEN` (en el payload, no requiere sesión). Es aditiva e idempotente:
nunca borra datos ni baja roles. **Por defecto es `dryRun`**; solo `dryRun: false` escribe. Opcionalmente
`renameLogins: [{fromEmail, username}]` pasa cuentas antiguas creadas con correo real a `usuario@cmo.com`
(mismo uid, contraseña y datos).

```bash
curl -s -X POST "https://us-central1-pasaportemisionerovirtual.cloudfunctions.net/runMigrations"   -H "Content-Type: application/json"   -d '{"data": {"token": "<MIGRATION_TOKEN>", "dryRun": true}}'
```

Ya se ejecutó en producción el 2026-10-07 y la función se eliminó después. Para volver a usarla:
`FUNCTIONS_DISCOVERY_TIMEOUT=120 firebase deploy --only functions:runMigrations`.
