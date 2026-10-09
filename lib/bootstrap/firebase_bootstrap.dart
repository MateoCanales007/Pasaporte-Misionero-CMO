import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// `--dart-define=USE_FIREBASE_EMULATORS=true` conecta la app (solo en debug)
/// a Firebase Emulator Suite para probar roles sin tocar producción.
const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _emulatorHostOverride = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Clave pública de reCAPTCHA v3 para App Check en web (`--dart-define`).
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Proyecto "demo-" de los emuladores: garantiza que nunca se toque producción.
const emulatorProjectId = 'demo-pasaporte-test';

Future<void> initializeFirebase() async {
  final useEmulators = kDebugMode && _useEmulators;
  final options = DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: useEmulators ? options.copyWith(projectId: emulatorProjectId) : options);

  // Caché local para funcionar sin conexión (también en web).
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (useEmulators) {
    await _connectToEmulators();
  }
  await _activateAppCheck();
}

Future<void> _connectToEmulators() async {
  final host = _emulatorHostOverride.isNotEmpty
      ? _emulatorHostOverride
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost');
  debugPrint('Usando Firebase Emulator Suite en $host');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, 5001);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}

/// Proveedores de depuración solo en modo debug; Play Integrity / reCAPTCHA en
/// release. Un fallo de App Check nunca impide abrir la app (la aplicación de
/// App Check se controla en el servidor).
Future<void> _activateAppCheck() async {
  if (_useEmulators && kDebugMode) return;
  try {
    if (kIsWeb) {
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
      } else if (_recaptchaSiteKey.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider(_recaptchaSiteKey));
      }
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
    );
  } catch (error) {
    debugPrint('App Check no se pudo activar: $error');
  }
}
