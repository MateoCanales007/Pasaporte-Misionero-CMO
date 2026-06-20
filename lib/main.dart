import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NUEVO
import 'firebase_options.dart';
import 'presentation/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Envolvemos la app en ProviderScope para activar Riverpod
  runApp(const ProviderScope(child: PasaporteApp()));
}

class PasaporteApp extends StatelessWidget {
  const PasaporteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasaporte Misionero CMO',
      debugShowCheckedModeBanner: false, // Quita la banda de debug
      theme: ThemeData(
        useMaterial3: true, // Forzamos Material 3 para los diseños modernos
        primaryColor: const Color(0xFF0E2C74),
      ),
      home: AuthScreen(),
    );
  }
}