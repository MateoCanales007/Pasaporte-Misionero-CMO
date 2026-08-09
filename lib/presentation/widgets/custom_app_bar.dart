import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/providers/passport_provider.dart';
import '../screens/create_stamp_screen.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passportAsync = ref.watch(userPassportProvider);
    final bool isAdmin = passportAsync.value?['isAdmin'] ?? false;

    return AppBar(
      backgroundColor: const Color(0xFF0E2C74),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const SizedBox(width: 10),
          const Text('Pasaporte Virtual CMO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        ],
      ),
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.add_location_alt, color: Color(0xFFC7A941)),
            tooltip: 'Crear nuevo sello',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStampScreen())),
          ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await AuthRepository().logoutUser();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}