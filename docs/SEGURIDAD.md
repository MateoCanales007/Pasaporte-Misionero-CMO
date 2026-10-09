# Seguridad: claves, secretos y App Check

## 1. Configuración pública vs. secretos

| Valor | Dónde está | ¿Es secreto? | Qué hacer |
|---|---|---|---|
| `apiKey` de Firebase Web (`AIzaSyCr6x…`) | `lib/firebase_options.dart`, `web/index.html` (Maps JS) | **No** (identifica el proyecto) | Restringir por dominio y por API (ver 3). **Rotarla**: se usó como clave de servidor de Places. |
| `apiKey` de Firebase Android (`AIzaSyDQwE…`) | `lib/firebase_options.dart`, `android/app/google-services.json`, `AndroidManifest.xml` (Maps) | **No** | Restringir a la app Android (paquete + SHA) y por API. |
| `apiKey` de iOS/macOS | `lib/firebase_options.dart` | **No** | Restringir al bundle `com.cmo.pasaporteMisioneroCmo`. |
| `PLACES_API_KEY` | Secret Manager (antes estaba escrita en `functions/src/index.ts`) | **Sí** | Debe ser una clave **nueva**, solo para Places API, usada únicamente por Functions. |
| `QR_SIGNING_SECRET` | Secret Manager | **Sí** | Firma los QR temporales. Mínimo 32 caracteres aleatorios. |
| `MIGRATION_TOKEN` | Secret Manager | **Sí** | Protege la función `runMigrations`. Puede borrarse al terminar la migración. |

La clave escrita en `functions/src/index.ts` **nunca se subió a git** (la carpeta `functions/` no estaba
versionada). Pero era **la misma** clave web pública que aparece en `lib/firebase_options.dart` y en
`web/index.html`, y esa sí está en el historial de git. Por eso debe considerarse expuesta: cualquiera podía
usarla para llamar a Places API y generar costos.

## 2. Pasos manuales pendientes en Google Cloud Console (en este orden)

> No los apliqué automáticamente: no hay `gcloud` en el equipo y la escritura en Secret Manager
> necesita tu autorización.

### 2.1 Crear la clave de servidor para Places
1. https://console.cloud.google.com/apis/credentials?project=pasaportemisionerovirtual
2. **Crear credenciales → Clave de API**. Nombre: `places-server (Cloud Functions)`.
3. **Restricciones de API:** solo *Places API*.
4. **Restricciones de aplicación:** *Ninguna*. Cloud Functions no tiene una IP fija; la clave
   queda protegida porque solo existe en Secret Manager.
5. Copia el valor y guárdalo como secreto (ver `docs/DESPLIEGUE.md`, paso 1).

### 2.2 Restringir la clave Web (`Browser key (auto created by Firebase)`)
- **Restricción de aplicación:** *Sitios web (HTTP referrers)*:
  - `https://pasaportemisionerovirtual.web.app/*`
  - `https://pasaportemisionerovirtual.firebaseapp.com/*`
  - `http://localhost/*` y `http://localhost:*/*` (solo si desarrollas en web)
- **Restricción de API:** Identity Toolkit API, Token Service API, Cloud Firestore API,
  Firebase Installations API, FCM Registration API, Firebase App Check API, Cloud Storage for
  Firebase API y Maps JavaScript API.
  **Quita Places API** de esta clave cuando Functions ya use la clave nueva.
- **Rotación:** Firebase permite crear una clave nueva para la app web, actualizar
  `firebase_options.dart`/`web/index.html` con `flutterfire configure` y después borrar la anterior.
  Hazlo después del despliegue de la nueva versión web para no cortar el servicio.

### 2.3 Restringir la clave Android (`Android key (auto created by Firebase)`)
- **Restricción de aplicación:** *Apps para Android*, paquete `com.cmo.pasaporte_misionero_cmo` con
  la huella **SHA-1** de:
  - la clave de *debug* de cada equipo de desarrollo (`cd android && ./gradlew signingReport`), y
  - la clave de *release*. Si usas Play App Signing, la de "App signing key certificate" de Play Console.
- **Restricción de API:** las mismas de Firebase anteriores + *Maps SDK for Android*.
- Hoy **no hay huellas SHA registradas** en Firebase (`firebase apps:android:sha:list` lo confirma).
  Regístralas: `firebase apps:android:sha:create 1:460417444897:android:c3881f86673176b8470760 <SHA256>`.
- Hoy la versión *release* se firma con la clave de debug (`android/app/build.gradle.kts`). Antes de
  publicar en Play Store crea una clave de release propia (fuera del repositorio).

## 3. Firebase App Check

El código ya está preparado (`lib/bootstrap/firebase_bootstrap.dart`):
- **Debug:** `AndroidDebugProvider` / `WebDebugProvider`. Al ejecutar en debug, el token de depuración
  aparece en Logcat o en la consola del navegador. Regístralo en *App Check → Apps → Administrar tokens de depuración*.
- **Release Android:** Play Integrity. Requiere la huella **SHA-256** registrada en Firebase y la app
  vinculada en Play Console.
- **Release Web:** reCAPTCHA v3. Crea la clave en https://www.google.com/recaptcha/admin (dominios del
  hosting), regístrala en *App Check → Web* y compila con
  `flutter build web --dart-define=RECAPTCHA_SITE_KEY=<clave pública>`.
- **Aplicación (enforcement):** las Functions leen `ENFORCE_APP_CHECK` de `functions/.env` (hoy en
  `false`). Cuando las métricas de App Check muestren que casi todas las solicitudes vienen verificadas:
  1. pon `ENFORCE_APP_CHECK=true` y vuelve a desplegar Functions;
  2. activa *Enforce* para Firestore y Storage en la consola de App Check.

## 4. Modelo de seguridad implementado

- **Roles** con Custom Claims (`role: admin | qrPresenter`), asignados solo por Functions
  (`setUserRole`, migración). Los campos `isAdmin`/`canShowQR` quedan como lectura histórica y no dan permisos.
- **Sellos**: el QR es un token firmado (HMAC-SHA256) que dura 60 s. `redeemStamp` valida firma,
  vigencia, estado y horario con la hora del servidor, e impide duplicados con una transacción y `create()`.
- **Reglas**: denegación por defecto, validación de campos/tipos/tamaños, perfiles privados solo para su
  dueño y los admin, y comunidad solo con `public_profiles` generados en el servidor.
- **Auditoría** (`audit_logs`): creación/edición de misiones, cambios de rol, códigos de recuperación,
  restablecimiento de contraseña y solicitudes de eliminación.
- **Recuperación de cuenta**: un admin genera un código temporal (30 min, máx. 5 intentos, guardado
  como hash). La respuesta es la misma si el usuario no existe. Al usarlo se revocan las sesiones abiertas.
