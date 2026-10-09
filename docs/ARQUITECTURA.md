# Arquitectura y contrato de datos — Pasaporte Misionero CMO

Este documento es la fuente de verdad del modelo de datos, roles y API de Cloud Functions.
Flutter, Functions y las reglas de seguridad deben respetarlo.

## 1. Principios

- **El servidor decide.** Sellos, roles, contadores y perfiles públicos solo se escriben desde
  Cloud Functions (Admin SDK). El cliente nunca otorga un sello ni se asigna un rol.
- **Hora del servidor.** Toda validación de horario usa la hora del servidor. Los instantes se
  guardan como `Timestamp` (UTC). La zona de negocio es `America/El_Salvador` (UTC−6, sin horario
  de verano); solo se usa para mostrar y capturar fechas.
- **Compatibilidad.** Se conservan las colecciones existentes (`user_passport`, `stamp`, `cell`) y
  los campos heredados (`stamps`, `isAdmin`, `canShowQR`). Nada se borra; la migración es aditiva e
  idempotente.
- **Privacidad.** Los datos privados (fecha de nacimiento, usuario, número interno, preferencias)
  viven en `user_passport/{uid}` y solo los leen su dueño y los administradores. La comunidad lee
  `public_profiles/{uid}`, que se genera en el servidor.

## 2. Roles

Se guardan como **Custom Claim** `role` en Firebase Auth:

| Rol           | Claim                  | Puede |
|---------------|------------------------|-------|
| `user`        | (sin claim)            | Ver contenido, misiones, comunidad visible, prédicas; escanear QR; diario; testimonios. |
| `qrPresenter` | `role: "qrPresenter"`  | Todo lo de `user` + mostrar el QR temporal de la misión activa. No crea ni edita sellos. |
| `admin`       | `role: "admin"`        | Todo + crear/editar sellos y prédicas, moderar testimonios, asignar/retirar `qrPresenter`, generar códigos de recuperación. |

- `setUserRole` (solo admin) asigna `user` o `qrPresenter` a usuarios que **no** son admin. La
  promoción a `admin` solo se hace con la migración (campo heredado `isAdmin`) o manualmente desde
  un entorno de servidor. Un admin no puede cambiar su propio rol.
- El servidor refleja el rol en `user_passport/{uid}.role` y aumenta `roleVersion`. La app escucha su
  documento; cuando `roleVersion` cambia ejecuta `getIdToken(true)` para refrescar los claims.

## 3. Colecciones

Notación: **S** = solo servidor escribe. **O** = el dueño puede escribir (con validación).
**A** = admin puede escribir (con validación).

### `user_passport/{uid}` — perfil privado
Lectura: dueño o admin.

| Campo | Tipo | Quién escribe | Notas |
|---|---|---|---|
| `id` | string | O (crear) | = uid (heredado) |
| `username` | string | O (crear) | Debe coincidir con el email `username@cmo.com` |
| `passportNumber` | string | O (crear) | `PM-AAAA-XXXX` |
| `fullName` | string 1..80 | O | |
| `nationality` | string 1..60 | O | |
| `dateOfBirth` | timestamp \| string ISO (heredado) | O (crear) | Privado. Nunca se publica. |
| `cellId` | string 0..80 | O | Id de `cell/{id}` o texto libre |
| `dateOfIssue` | timestamp \| string ISO (heredado) | O (crear) | |
| `stamps` | list | heredado | Solo lectura. En la creación debe ser `[]`. |
| `isAdmin`, `canShowQR` | bool | heredado (S) | Solo lectura. Ya no otorgan permisos. |
| `role` | `user`\|`qrPresenter`\|`admin` | S | Espejo del claim |
| `roleVersion` | int | S | |
| `stampCount` | int | S | |
| `lastRedemptionAt` | timestamp | S | |
| `communityVisible` | bool | O | Aparecer en Comunidad (por defecto `true`) |
| `showNationality` | bool | O | Por defecto `false` |
| `showCell` | bool | O | Por defecto `true` |
| `notificationPrefs` | map | O | `{newMission, missionReminder, newSermon, stampConfirmed}` (bool) |
| `deletionRequestedAt` | timestamp | S | |
| `createdAt` | timestamp | O (crear) | `== request.time` |
| `updatedAt` | timestamp | O | `== request.time` |

Campos editables por el dueño en `update`: `fullName`, `nationality`, `cellId`,
`communityVisible`, `showNationality`, `showCell`, `notificationPrefs`, `updatedAt`.

#### `user_passport/{uid}/redemptions/{missionId}` — sellos obtenidos (S)
Lectura: dueño o admin. Escritura: **solo servidor**.

| Campo | Tipo |
|---|---|
| `missionId` | string |
| `userId` | string |
| `missionName` | string (copia al momento) |
| `status` | `confirmed` |
| `source` | `qr` \| `legacy_migration` |
| `redeemedAt` | timestamp \| null (null solo si el dato heredado estaba corrupto) |
| `createdAt` | timestamp (servidor) |
| `tokenId` | string \| null (nonce del QR) |
| `tokenIssuedAt` | timestamp \| null |
| `validatedBy` | string \| null (uid del presentador que emitió el QR) |
| `appVersion` | string \| null |
| `platform` | string \| null |
| `legacyDateMissing` | bool (solo migración) |

#### `user_passport/{uid}/journal/{entryId}` — diario privado (O)
Solo el dueño lee y escribe.
`text` (1..5000), `missionId` (string\|null), `missionName` (string\|null),
`createdAt` (`== request.time` al crear), `updatedAt` (`== request.time`).

#### `user_passport/{uid}/fcm_tokens/{token}` — dispositivos (O)
`token` (== id del documento, ≤ 4096), `platform` (`android`\|`web`\|`ios`), `updatedAt` (`== request.time`).
Un trigger suscribe el token a los temas según `notificationPrefs`.

### `public_profiles/{uid}` — perfil público (S)
Lectura: usuario autenticado si `communityVisible == true`; el dueño y los admin siempre.

`uid`, `displayName`, `initials`, `cellName` (string\|null; solo si `showCell`),
`nationality` (string\|null; solo si `showNationality`), `stampCount` (int),
`stampIds` (list<string>, máx. 200), `communityVisible` (bool), `updatedAt`.

### `stamp/{missionId}` — catálogo de misiones/sellos (S)
Lectura: usuario autenticado. Escritura: **solo** `saveMission` / `setMissionStatus`.

| Campo | Tipo |
|---|---|
| `name` | string 2..80 |
| `isoCode` | string `^[A-Z]{2,6}$` |
| `image` | string (`''` o URL https) |
| `location` | GeoPoint |
| `placeId` | string \| ausente |
| `schedule` | list `{start: Timestamp, end: Timestamp}` (1..20, sin solaparse, start < end) |
| `status` | `draft` \| `active` \| `inactive` |
| `active` | bool (= `status == 'active'`, compatibilidad) |
| `createdBy`, `updatedBy` | uid |
| `createdAt`, `updatedAt` | timestamp (servidor) |
| `announcedAt` | timestamp (servidor, notificación enviada) |

"Finalizada" se deriva: todas las ventanas terminaron. Los borradores se ocultan en la interfaz
para quien no es admin (el catálogo no contiene datos sensibles).

### `cell/{cellId}`
`name`. Lectura: autenticado. Escritura: nadie desde el cliente.

### `sermons/{sermonId}` — prédicas (A)
Lectura: autenticado si `active == true`; admin siempre.

| Campo | Tipo |
|---|---|
| `sourceUrl` | string https, ≤ 2048 |
| `title` | string 1..200 |
| `coverImageUrl` | string (`''` o https), ≤ 2048 |
| `coverStoragePath` | string \| null (`sermon_covers/{sermonId}/...`) |
| `thumbnailUrl` | string (`''` o https) |
| `platform` | `youtube` \| `vimeo` \| `facebook` \| `other` |
| `domain` | string ≤ 253 |
| `externalVideoId` | string \| null |
| `publishedAt` | timestamp |
| `active` | bool |
| `deleted` | bool (borrado recuperable; si `true` entonces `active == false`) |
| `deletedAt` | timestamp \| null |
| `sortOrder` | int (opcional) |
| `createdBy`, `updatedBy` | uid de quien escribe |
| `createdAt` | timestamp (`== request.time` al crear, inmutable) |
| `updatedAt` | timestamp (`== request.time`) |
| `announcedAt` | timestamp (solo servidor) |

### `testimonials/{id}` — testimonios moderados
- Crear: autenticado; `userId == uid`, `status == 'pending'`, `text` 10..1000,
  `displayName` 1..80, `missionId` string\|null, `createdAt == request.time`.
- Leer: `status == 'approved'`, o el autor, o admin.
- Actualizar: solo admin y solo `status` (`approved`\|`rejected`), `moderatedBy` (== uid),
  `moderatedAt` (`== request.time`).
- Borrar: autor o admin.

### Colecciones solo-servidor
`audit_logs/{id}` (lectura admin), `deletion_requests/{uid}` (lectura dueño/admin),
`recovery_codes/{uid}`, `notification_log/{key}`, `_migrations/{runId}`. Nadie escribe desde el cliente.

## 4. Storage

| Ruta | Lectura | Escritura |
|---|---|---|
| `sermon_covers/{sermonId}/{file}` | autenticado | admin; `image/(jpeg\|png\|webp)`; < 5 MB |
| `mission_images/{missionId}/{file}` | autenticado | admin; `image/(jpeg\|png\|webp)`; < 5 MB |
| `mission_service_photos/{missionId}/{file}` (fotos del culto de la misión; se listan) | autenticado | admin; `image/(jpeg\|png\|webp)`; original < 25 MB |
| `sermon_photos/{sermonId}/{file}` (fotos del culto de la prédica; se listan) | autenticado | admin; `image/(jpeg\|png\|webp)`; original < 25 MB |
| todo lo demás | no | no |

## 5. Token QR

Formato: `PMCMO1.<payload base64url>.<firma base64url>`

- `payload` = JSON `{ "v": 1, "m": missionId, "iat": ms, "exp": ms, "n": nonce, "p": presenterUid }`
- Firma = HMAC-SHA256(`QR_SIGNING_SECRET`, `"PMCMO1." + payload`), comparación en tiempo constante.
- Vigencia: **60 s**. La pantalla del presentador renueva a los 30 s (`refreshAfterMs`).
- Al canjear se acepta hasta `exp + 15 s` (latencia de red), medido con la hora del servidor.
- El QR es compartido por toda la congregación: el nonce sirve para auditoría, no es de un solo uso.
  El duplicado se impide por usuario y misión (`redemptions/{missionId}`) dentro de una transacción.

## 6. Cloud Functions (región `us-central1`)

Todas las *callables* exigen autenticación salvo `redeemRecoveryCode`. Los resultados de negocio
esperados se devuelven como `{status: ...}`; las violaciones de permisos o entrada inválida usan
`HttpsError` (`unauthenticated`, `permission-denied`, `invalid-argument`, `not-found`).

| Función | Rol | Entrada | Salida |
|---|---|---|---|
| `issueQrToken` | admin, qrPresenter | `{missionId?}` | `{status:'ok', token, missionId, missionName, issuedAt, expiresAt, refreshAfterMs}` \| `{status:'noActiveMission'}` \| `{status:'chooseMission', missions:[{id,name}]}` |
| `redeemStamp` | autenticado | `{token, appVersion?, platform?}` | `{status:'confirmed'\|'alreadyRedeemed', missionId, missionName, redeemedAt}` \| `{status:'expired'\|'invalid'\|'notFound'}` \| `{status:'inactive'\|'outsideSchedule', missionName}` |
| `saveMission` | admin | `{missionId?, name, isoCode, image, location:{lat,lng}, placeId?, schedules:[{start,end}] (ms), status}` | `{missionId}` |
| `setMissionStatus` | admin | `{missionId, status}` | `{missionId, status}` |
| `setUserRole` | admin | `{uid, role:'user'\|'qrPresenter'}` | `{uid, role}` |
| `fetchVideoMetadata` | admin | `{url}` | `{status:'ok', platform, domain, externalVideoId, title, thumbnailUrl, authorName, canonicalUrl, metadataAvailable}` \| `{status:'invalidUrl', reason}` |
| `createRecoveryCode` | admin | `{uid}` | `{code, expiresAt}` |
| `redeemRecoveryCode` | público | `{username, code, newPassword}` | `{status:'ok'\|'invalid'\|'weakPassword'}` (misma respuesta si el usuario no existe) |
| `requestAccountDeletion` | autenticado | `{reason?}` | `{status:'ok'}` |
| `searchPlaces` | admin | `{query}` | `{success, predictions:[{description, place_id}]}` |
| `getPlaceDetails` | admin | `{placeId}` | `{success, location:{lat,lng}}` |
| `getPhotoReferences` | autenticado | `{placeId?, lat?, lng?}` | `{success, references: string[]}` |
| `getMissionPlacePhoto` | autenticado | `{photoReference}` | `{success, imageBase64}` |

Triggers y tareas:
- `onUserPassportWritten` → sincroniza `public_profiles/{uid}` y los temas FCM si cambian las preferencias.
- `onFcmTokenWritten` → suscribe/desuscribe el token a los temas `missions`, `mission_reminders`, `sermons`.
- `onMissionWritten` → notifica "Nueva misión" al activarse por primera vez (`announcedAt`).
- `onSermonWritten` → notifica "Nueva prédica" al publicarse por primera vez (`announcedAt`).
- `sendMissionReminders` (cada 15 min) → avisa misiones que inician en la próxima hora.
- `runMigrations` (HTTP, protegido con `MIGRATION_TOKEN`) → migración idempotente; `dryRun` por defecto.

Secretos (Secret Manager): `QR_SIGNING_SECRET`, `PLACES_API_KEY`, `MIGRATION_TOKEN`.

## 7. Flutter

```
lib/
  core/          tema, colores, espaciados, errores de dominio, utilidades (fechas, URLs, zona horaria)
  domain/        modelos tipados, contratos de repositorios, casos de uso (sin Firebase)
  data/          implementaciones Firebase/locales de los repositorios y mapeadores
  presentation/  providers (Riverpod), pantallas y widgets
```

- Las pantallas no importan `cloud_firestore` ni `cloud_functions`: usan providers que exponen
  repositorios del dominio. Las pruebas reemplazan los repositorios con `ProviderScope(overrides:)`.
- Mapeadores robustos: un dato obligatorio corrupto produce `DataParseException`; nunca se sustituye
  por la fecha actual.

## 8. Notas de implementación

- `issueQrToken` además rechaza a un `qrPresenter` cuyo `user_passport.role` ya no es de presentador
  (cubre la hora que tarda en refrescarse el token después de retirar el permiso).
- `onMissionWritten` solo anuncia cuando una misión **pasa** a activa (la migración que agrega `status`
  a misiones antiguas no dispara avisos). Los anuncios reservan su turno con una transacción para no
  repetirse.
- En el emulador (`FUNCTIONS_EMULATOR=true`) no se envían notificaciones FCM reales.
- `runMigrations` es `dryRun` por defecto y, tras escribir, vuelve a planificar para verificar
  (`verification.pendingWrites` debe ser `0`).
- `fetchVideoMetadata.reason` devuelve códigos (`notHttps`, `credentials`, `invalidVideoId`, …) que la
  app traduce a mensajes en español.
- Los escaneos sin conexión se guardan en el almacenamiento privado de la app (`shared_preferences`),
  separados por usuario. El token dura 60 s, está firmado y solo sirve con la sesión del propio usuario.
- Pruebas: `flutter test` (unitarias, repositorios con `fake_cloud_firestore`, widgets y diseño con letra
  al 150 %), `functions/` (`node:test`) y `tests/firebase/` (reglas e integración con emuladores).
