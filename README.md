# 🛂 Pasaporte Misionero Virtual - CMO

**Centro Misionero Oasis (CMO)**

Aplicación para registrar la participación misionera. Funciona como una bitácora de intercesión digital: los
misioneros coleccionan sellos al escanear el código QR que se muestra en el culto. También incluye prédicas,
comunidad, testimonios y un diario privado de oración.

Está pensada para personas de todas las edades: letra grande, botones amplios, textos claros y confirmaciones
antes de cualquier acción importante.

## Tecnologías

- **App:** Flutter 3.44 (Android y Web), Riverpod 3, arquitectura por capas (`core` / `domain` / `data` / `presentation`).
- **Backend:** Firebase Auth, Cloud Firestore, Cloud Functions (Node 24, TypeScript), Cloud Messaging, Storage, App Check.
- **Seguridad:** roles con Custom Claims, QR temporal firmado por el servidor, reglas de Firestore/Storage con pruebas.

Documentación:
- [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md): modelo de datos, roles y API de Functions.
- [`docs/SEGURIDAD.md`](docs/SEGURIDAD.md): claves, secretos, App Check y pasos en la consola.
- [`docs/DESPLIEGUE.md`](docs/DESPLIEGUE.md): orden de despliegue, migración y corte.
- [`functions/README.md`](functions/README.md) y [`tests/firebase/README.md`](tests/firebase/README.md).

## Ejecutar desde Android Studio

1. Requisitos: Flutter 3.44.x, Android Studio con los plugins de Flutter y Dart, un emulador o un teléfono
   con depuración USB.
2. **File → Open…** y elige la carpeta del proyecto.
3. En la terminal de Android Studio: `flutter pub get`.
4. Elige el dispositivo en la barra superior y pulsa **Run ▶** (configuración `main.dart`).
5. Para Web: elige *Chrome (web)* como dispositivo, o `flutter run -d chrome`.

### Usar los emuladores de Firebase (recomendado para probar roles)

```bash
npm --prefix functions install && npm --prefix functions run build
cp functions/.secret.local.example functions/.secret.local   # valores de prueba
firebase emulators:start --only auth,firestore,functions,storage --project demo-pasaporte-test
```

En Android Studio, en *Run → Edit Configurations… → Additional run args*, agrega:
`--dart-define=USE_FIREBASE_EMULATORS=true`. Si usas un teléfono físico, agrega también
`--dart-define=FIREBASE_EMULATOR_HOST=<IP de tu PC>`. Esto solo funciona en modo debug y nunca toca
producción.

## Cómo probar cada rol

Los roles viven en Custom Claims y solo los asigna el servidor:

| Rol | Cómo obtenerlo | Qué probar |
|---|---|---|
| **Misionero** (`user`) | Registrarse en la app | Ver Pasaporte, Misiones, Prédicas y Comunidad. Escanear un QR (botón **ESCANEAR SELLO**). Diario, testimonios, privacidad, avisos. |
| **Presentador de QR** | Un admin lo activa en *Comunidad → perfil → Presentador de QR* (o en el emulador: `node scripts/set-role-emulator.mjs <usuario> qrPresenter`) | Botón **MOSTRAR QR**: el código se renueva cada 30 s y vence a los 60 s. No puede crear ni editar misiones. |
| **Administrador** | En producción, la migración convierte `isAdmin: true` en el claim `admin`. En el emulador: `cd tests/firebase && node scripts/set-role-emulator.mjs <usuario> admin` | Crear, editar y duplicar misiones con varios horarios. Publicar prédicas (título automático de YouTube). Moderar testimonios. Asignar presentadores. Generar códigos de recuperación. |

Flujo completo: el admin crea una misión activa con horario vigente → el presentador abre **MOSTRAR QR** →
el misionero escanea → el servidor confirma el sello, que aparece en *Pasaporte → Mis sellos*.

Sin conexión el escaneo queda **"Pendiente de validación"** (nunca como sello confirmado) y se reintenta solo al
volver internet. Si el código vence antes, la app pide escanear de nuevo.

## Descargar la app

La APK para Android está siempre en `https://pasaportemisionerovirtual.web.app/descargar/PasaporteCMO.apk`
(también desde *Perfil → Descargar la app*). Para publicar una versión nueva: `bash scripts/publicar_web.sh`.

## Recuperar una contraseña

1. El misionero toca **¿Olvidaste tu contraseña?** y escribe a soporte por WhatsApp.
2. El admin confirma su identidad y, en *Comunidad → perfil → Ayudar a recuperar acceso*, genera un código
   temporal (30 minutos).
3. El misionero escribe ese código y su nueva contraseña en la app. Nadie más conoce la contraseña.

## Pruebas

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test                                   # unitarias + widgets
npm --prefix functions run lint && npm --prefix functions test
cd tests/firebase && npm install && npm test   # reglas + integración (emuladores)
```

GitHub Actions (`.github/workflows/ci.yml`) ejecuta todo esto en cada push o pull request. CI no despliega.
