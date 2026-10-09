import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/repository_providers.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/session_router.dart';

/// Permite mostrar avisos (p. ej. notificaciones en primer plano) desde
/// cualquier parte de la app.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PasaporteApp extends StatelessWidget {
  const PasaporteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasaporte Misionero CMO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Decide la primera pantalla una sola vez. Después, la navegación la manejan
/// el login (al terminar su animación) y el cierre de sesión.
///
/// La sesión se lee directamente del repositorio: un `StreamProvider` sin
/// oyentes queda en pausa en Riverpod 3 y nunca completaría su `.future`.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final Future<bool> _signedIn = ref
      .read(authRepositoryProvider)
      .watchIdentity()
      .first
      .then((identity) => identity != null)
      .timeout(const Duration(seconds: 15), onTimeout: () => false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _signedIn,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        return snapshot.data == true ? const SessionRouter() : const AuthScreen();
      },
    );
  }
}

/// Pantalla mostrada si Firebase no pudo inicializarse.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No pudimos iniciar la aplicación.\nRevisa tu conexión a internet y vuelve a abrirla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}
