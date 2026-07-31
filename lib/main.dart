import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/session_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    runApp(const ProviderScope(child: PasaporteApp()));
  } catch (e) {
    debugPrint("Error crítico en inicialización: $e");
  }
}

class PasaporteApp extends StatelessWidget {
  const PasaporteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasaporte Misionero CMO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0E2C74),
      ),
      // ✨ LA SOLUCIÓN: Revisamos el estado de sesión SOLO UNA VEZ.
      // Esto evita que la pantalla se destruya de golpe al loguearse,
      // dándole tiempo a flutter_login de hacer su animación del cuadrado.
      home: FutureBuilder<User?>(
        future: FirebaseAuth.instance.authStateChanges().first,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(backgroundColor: Color(0xFF0E2C74));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const SessionRouter();
          }
          return AuthScreen();
        },
      ),
    );
  }
}