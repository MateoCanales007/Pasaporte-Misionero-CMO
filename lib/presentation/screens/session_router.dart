import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/passport_provider.dart';
import 'home_screen.dart';
import 'complete_profile_screen.dart';

class SessionRouter extends ConsumerWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Vigila la base de datos en tiempo real
    final passportAsync = ref.watch(userPassportProvider);

    return passportAsync.when(
      loading: () => const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (passportData) {
        // Si el documento NO existe, significa que es un usuario recién registrado
        if (passportData == null) {
          return const CompleteProfileScreen();
        }
        // Si ya tiene datos, lo manda al pasaporte 3D directamente
        return const HomeScreen();
      },
    );
  }
}