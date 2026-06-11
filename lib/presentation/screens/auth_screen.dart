import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import '../../data/repositories/auth_repository.dart';
import 'session_router.dart'; // El nuevo archivo que crearemos

class AuthScreen extends StatelessWidget {
  AuthScreen({super.key});

  final AuthRepository _authRepo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      logo: const AssetImage('assets/images/cmo.png'),
      onLogin: (data) => _authRepo.loginUser(data.name, data.password),
      // Solo registra el correo y contraseña
      onSignup: (data) => _authRepo.registerUser(data.name!, data.password!),
      onSubmitAnimationCompleted: () {
        // En lugar de ir al Home, vamos al Enrutador Inteligente
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SessionRouter()),
              (route) => false,
        );
      },
      onRecoverPassword: (_) async => null,
      theme: LoginTheme(
        primaryColor: const Color(0xFF0E2C74),
        accentColor: const Color(0xFFC7A941),
        pageColorLight: Colors.white,
        pageColorDark: Colors.white,
      ),
    );
  }
}