import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/passport_provider.dart';
import 'home_screen.dart';
import 'complete_profile_screen.dart';

class SessionRouter extends ConsumerWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passportAsync = ref.watch(userPassportProvider);

    return passportAsync.when(
      // ✨ Cero transiciones extra, cero círculos.
      // Solo el color base para sostener la ilusión del cuadrado de flutter_login.
      loading: () => const Scaffold(backgroundColor: Color(0xFF0E2C74)),

      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),

      data: (passportData) {
        if (passportData == null) {
          return const CompleteProfileScreen();
        }
        return const HomeScreen();
      },
    );
  }
}