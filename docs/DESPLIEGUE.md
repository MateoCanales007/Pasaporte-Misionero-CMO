# Despliegue y corte a la nueva versión

Estado al 2026-10-07:

| Paso | Estado |
|---|---|
| Índices de Firestore | ✅ Desplegados |
| Secretos en Secret Manager (`QR_SIGNING_SECRET`, `PLACES_API_KEY`, `MIGRATION_TOKEN`) | ✅ Creados |
| Cloud Functions (18) | ✅ Desplegadas |
| Migración | ✅ Ejecutada (run `2026-10-08T03-20-39-710Z_a94576`): 16 sellos copiados, 3 admins, 54 perfiles, 3 cuentas Gmail pasadas a usuario; verificación 0 pendientes |
| Reglas de Firestore | ✅ Desplegadas |
| Hosting (web) | ✅ Publicado |
| `runMigrations` | ✅ Eliminada tras usarla (el código sigue en el repo) |
| Firebase Storage + reglas | ✅ Activado y reglas desplegadas (portadas, imágenes y fotos del culto) |
| APK descargable | ✅ `https://pasaportemisionerovirtual.web.app/descargar/PasaporteCMO.apk` |
| Restringir claves y App Check | ⏳ Pendiente (docs/SEGURIDAD.md) |

> En esta PC el despliegue de Functions necesita `FUNCTIONS_DISCOVERY_TIMEOUT=120` (la carga tarda más
> de 10 s). La cuenta que despliega necesita el rol *Secret Manager Admin*.

Respaldo de las reglas anteriores: `docs/respaldos/reglas-2026-10-06/`.

## Publicar una nueva versión (web + APK)

1. Sube el número de versión en `pubspec.yaml` (por ejemplo `1.1.0+2` → `1.2.0+3`).
2. Ejecuta `bash scripts/publicar_web.sh`. Compila la APK y la web, copia la APK a
   `build/web/descargar/PasaporteCMO.apk` y publica en Firebase Hosting.

El botón **Perfil → Descargar la app** siempre apunta al mismo enlace, así que todos reciben la versión
nueva sin cambiar nada. El servidor entrega la APK con `Content-Disposition: attachment` y sin caché.

## Paso 1 — Secretos (una sola vez)

Desde la raíz del repositorio. Cada comando pide el valor; pégalo, no lo escribas en archivos.

```bash
# Genera un valor aleatorio (ejecútalo dos veces: uno para cada secreto)
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"

firebase functions:secrets:set QR_SIGNING_SECRET
firebase functions:secrets:set MIGRATION_TOKEN     # guarda este valor para el paso 3
firebase functions:secrets:set PLACES_API_KEY      # clave NUEVA de servidor (docs/SEGURIDAD.md §2.1)
```

> Para no cortar el buscador de lugares mientras creas la clave nueva, puedes usar temporalmente
> la clave actual de Places y reemplazarla después con `secrets:set` + `firebase deploy --only functions`.

## Paso 2 — Functions (compatible con la app actual)

```bash
firebase deploy --only functions
```

No afecta a las versiones instaladas de la app: las 4 funciones de Places conservan su nombre
y su respuesta, y las funciones nuevas no las usa nadie todavía.

## Paso 3 — Migración (aditiva e idempotente)

```bash
export MIGRATION_TOKEN='<valor del paso 1>'
URL="https://us-central1-pasaportemisionerovirtual.cloudfunctions.net/runMigrations"

# 3.1 Ensayo: no escribe nada
curl -s -X POST "$URL" -H "Authorization: Bearer $MIGRATION_TOKEN" \
  -H "Content-Type: application/json" -d '{"dryRun": true}'
```

Antes de ejecutarla de verdad, revisa:
- `claimsToSet.admin` y `claimsToSet.qrPresenter`: cuántas personas recibirán cada rol. Las reglas
  anteriores permitían que cualquier usuario se pusiera `isAdmin: true` en su documento. Compara esa
  cantidad con los documentos de `user_passport` que tienen `isAdmin == true` o `canShowQR == true` en la
  consola de Firestore, y corrige cualquier caso sospechoso antes de migrar.
- `legacyEntries` / `redemptionsToCreate`: sellos del arreglo antiguo que se copiarán a `redemptions`.
- `unknownMissionRefs` y `corruptedDates`: datos dañados. Se conservan sin inventar fechas.

```bash
# 3.2 Ejecución real
curl -s -X POST "$URL" -H "Authorization: Bearer $MIGRATION_TOKEN" \
  -H "Content-Type: application/json" -d '{"dryRun": false}'

# 3.3 Verificación: repetirla no debe escribir nada (todo en 0)
curl -s -X POST "$URL" -H "Authorization: Bearer $MIGRATION_TOKEN" \
  -H "Content-Type: application/json" -d '{"dryRun": true}'
```

El resultado debe incluir `verification.allLegacyEntriesHaveRedemption: true` y
`verification.pendingWrites: 0`. El campo antiguo `stamps` **no se borra**.

## Paso 4 — Corte (el mismo día, en este orden)

Las reglas nuevas bloquean lo que la app antigua hacía de forma insegura:
- leer `user_passport` antes de iniciar sesión (el registro antiguo deja de funcionar);
- listar todos los pasaportes en Comunidad;
- escribir sellos y roles desde el teléfono.

Por eso las reglas se publican junto con la app nueva:

```bash
flutter build web --release
firebase deploy --only firestore:rules,hosting
flutter build apk --release        # o appbundle para Play Store
```

Distribuye el APK nuevo ese mismo día. Pide a los usuarios Android que actualicen.

**Reversión de emergencia:** copia `docs/respaldos/reglas-2026-10-06/firestore.rules.desplegadas`
sobre `firestore.rules` y ejecuta `firebase deploy --only firestore:rules`. Ningún dato se pierde.

## Paso 5 — Storage (portadas e imágenes)

1. https://console.firebase.google.com/project/pasaportemisionerovirtual/storage → **Comenzar**.
   Usa el bucket por defecto `pasaportemisionerovirtual.firebasestorage.app`.
2. `firebase deploy --only storage`

Mientras tanto la app funciona igual: las prédicas usan la miniatura de YouTube y las misiones
aceptan una URL de imagen. Solo el botón "Subir" mostrará un error amigable.

## Paso 6 — Limpieza opcional

```bash
firebase functions:delete runMigrations
firebase functions:secrets:destroy MIGRATION_TOKEN
```

## Paso 7 — Seguridad de claves y App Check

Sigue `docs/SEGURIDAD.md`: restringir claves, registrar huellas SHA, reCAPTCHA y activar
App Check gradualmente.
