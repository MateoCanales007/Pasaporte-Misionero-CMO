import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/support_contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../providers/repository_providers.dart';
import '../session_router.dart';

/// Inicio de sesión, registro y recuperación de acceso.
///
/// Recuperación: el usuario escribe a soporte por WhatsApp; un administrador
/// verifica su identidad y le entrega un código temporal. Con ese código el
/// propio usuario elige su nueva contraseña (nadie más la conoce).
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authRepositoryProvider);

    return Shortcuts(
      // Los nombres de usuario no llevan espacios.
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.space): const DoNothingAndStopPropagationIntent(),
      },
      child: FlutterLogin(
        title: '',
        logo: const AssetImage('assets/images/cmo.png'),
        userType: LoginUserType.name,
        userValidator: (value) => (value == null || value.trim().isEmpty) ? 'Escribe tu nombre de usuario' : null,
        passwordValidator: (value) => (value == null || value.isEmpty) ? 'Escribe tu contraseña' : null,
        onLogin: (data) => auth.login(data.name, data.password),
        onSignup: (data) => auth.register(data.name ?? '', data.password ?? ''),
        onRecoverPassword: _openSupportChat,
        onConfirmRecover: (code, data) => _confirmRecover(auth, code, data),
        onSubmitAnimationCompleted: () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SessionRouter()));
        },
        theme: LoginTheme(
          pageColorLight: Colors.white,
          pageColorDark: Colors.white,
          primaryColor: AppColors.navy,
          accentColor: AppColors.amber,
          errorColor: AppColors.error,
          cardTheme: const CardTheme(color: AppColors.navy, elevation: 8, margin: EdgeInsets.only(top: 15)),
          buttonTheme: const LoginButtonTheme(backgroundColor: AppColors.orange),
          titleStyle: const TextStyle(color: Colors.white),
          bodyStyle: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
          textFieldStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
          buttonStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onOrange),
          switchAuthTextColor: Colors.white,
          inputTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 17),
            errorStyle: const TextStyle(color: AppColors.amber, fontSize: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        messages: LoginMessages(
          userHint: 'Nombre de usuario',
          passwordHint: 'Contraseña',
          confirmPasswordHint: 'Confirmar contraseña',
          loginButton: 'INICIAR SESIÓN',
          signupButton: 'CREAR CUENTA',
          goBackButton: 'VOLVER',
          confirmPasswordError: 'Las contraseñas no coinciden',
          forgotPasswordButton: '¿Olvidaste tu contraseña?',
          recoverPasswordButton: 'PEDIR AYUDA POR WHATSAPP',
          recoverPasswordIntro: 'Recuperar el acceso',
          recoverCodePasswordDescription:
              'Escribe tu nombre de usuario y toca el botón. Se abrirá WhatsApp para que el equipo de soporte '
              'te dé un código temporal.',
          recoverPasswordDescription: 'Escribe tu nombre de usuario y toca el botón para pedir ayuda por WhatsApp.',
          recoverPasswordSuccess: 'Abriendo WhatsApp…',
          confirmRecoverIntro: 'Escribe el código que te dio soporte y elige tu nueva contraseña.',
          recoveryCodeHint: 'Código de recuperación',
          recoveryCodeValidationError: 'Escribe el código que recibiste',
          setPasswordButton: 'GUARDAR CONTRASEÑA',
          confirmRecoverSuccess: '¡Listo! Ya puedes iniciar sesión con tu nueva contraseña.',
          flushbarTitleError: 'Atención',
          flushbarTitleSuccess: 'Listo',
          signUpSuccess: 'Cuenta creada',
        ),
      ),
    );
  }

  Future<String?> _openSupportChat(String username) async {
    final opened = await SupportContact.openWhatsApp(
      'Hola, soy el usuario "${username.trim()}" y necesito un código para recuperar el acceso a mi '
      'Pasaporte Misionero Virtual.',
    );
    return opened ? null : 'No se pudo abrir WhatsApp. Escríbenos al ${SupportContact.displayPhone}.';
  }

  Future<String?> _confirmRecover(AuthRepository auth, String code, LoginData data) async {
    try {
      final result = await auth.recoverWithCode(username: data.name, code: code, newPassword: data.password);
      return switch (result) {
        PasswordRecoveryResult.success => null,
        PasswordRecoveryResult.weakPassword => 'La contraseña debe tener al menos 6 caracteres.',
        PasswordRecoveryResult.invalidCode =>
          'El usuario o el código no son correctos, o el código ya venció. Pide uno nuevo a soporte.',
      };
    } catch (error) {
      return friendlyErrorMessage(error);
    }
  }
}
