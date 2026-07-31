import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:url_launcher/url_launcher.dart'; // ✨ IMPORTANTE: Para abrir WhatsApp
import '../../data/repositories/auth_repository.dart';
import 'session_router.dart';

class AuthScreen extends StatelessWidget {
  AuthScreen({super.key});

  final AuthRepository _authRepo = AuthRepository();

  // METODO PARA ABRIR WHATSAPP
  Future<String?> _launchWhatsApp(String username) async {
    // Limpiamos el nombre de usuario
    final cleanUsername = username.trim();

    // Preparamos el mensaje predeterminado
    final String message = 'Hola, soy el usuario "$cleanUsername" y necesito ayuda para recuperar la contraseña de mi Pasaporte Misionero Virtual.';

    // Formato de URL para WhatsApp (Reemplaza los X con el número real de soporte de la iglesia)
    final Uri whatsappUrl = Uri.parse('https://wa.me/50370969099?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return null; // Retornar null le dice a flutter_login que la acción fue un "éxito"
      } else {
        return 'No se pudo abrir WhatsApp. Contáctanos al 50370969099';
      }
    } catch (e) {
      return 'Error al intentar abrir WhatsApp.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.space): const DoNothingAndStopPropagationIntent(),
      },
      child: FlutterLogin(
        title: '',
        logo: const AssetImage('assets/images/cmo.png'),
        userType: LoginUserType.name,

        userValidator: (value) => null,
        passwordValidator: (value) => null,

        onLogin: (data) => _authRepo.loginUser(data.name, data.password),
        onSignup: (data) => _authRepo.registerUser(data.name!, data.password!),

        onSubmitAnimationCompleted: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SessionRouter()),
          );
        },

        // ✨ AQUÍ INTERCEPTAMOS EL BOTÓN DE RECUPERAR
        onRecoverPassword: _launchWhatsApp,

        theme: LoginTheme(
          pageColorLight: Colors.white,
          pageColorDark: Colors.white,
          primaryColor: const Color(0xFF0E2C74),
          cardTheme: const CardTheme(
            color: Color(0xFF0E2C74),
            elevation: 8,
            margin: EdgeInsets.only(top: 15),
          ),
          buttonTheme: const LoginButtonTheme(
            backgroundColor: Color(0xFFF58B27),
          ),
          titleStyle: const TextStyle(color: Colors.white),
          bodyStyle: const TextStyle(color: Colors.white),
          textFieldStyle: const TextStyle(color: Colors.black87),

          inputTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // ✨ AQUÍ CAMBIAMOS LOS TEXTOS DE LA PANTALLA DE RECUPERACIÓN
        messages: LoginMessages(
          userHint: 'Nombre de usuario (ej. mateo_cmo)',
          passwordHint: 'Contraseña',
          confirmPasswordHint: 'Confirmar contraseña',
          loginButton: 'INICIAR SESIÓN',
          signupButton: 'REGISTRARSE',
          goBackButton: 'VOLVER',
          confirmPasswordError: 'Las contraseñas no coinciden',

          // Textos específicos para la vista de "Olvidé mi contraseña"
          forgotPasswordButton: '¿Olvidaste tu contraseña?',
          recoverPasswordButton: 'CONTACTAR SOPORTE',
          recoverPasswordIntro: 'Recuperación de acceso',
          recoverPasswordDescription: 'Ingresa tu nombre de usuario y presiona el botón. Te redirigiremos a WhatsApp para asignarte una nueva contraseña.',
          recoverPasswordSuccess: '¡Abriendo WhatsApp!',
        ),
      ),
    );
  }
}