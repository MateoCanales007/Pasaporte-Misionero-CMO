import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'presentation/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  try {
    await initializeFirebase();
  } catch (error) {
    debugPrint('Error crítico en inicialización: $error');
    runApp(const StartupErrorApp());
    return;
  }

  var version = 'dev';
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    // La versión solo se usa para auditoría; no es crítica.
  }

  runApp(ProviderScope(overrides: [appVersionProvider.overrideWithValue(version)], child: const PasaporteApp()));
}
