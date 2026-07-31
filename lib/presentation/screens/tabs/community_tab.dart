import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/community_provider.dart';
import '../../../domain/models/user_passport.dart';
import '../user_detail_screen.dart';

class CommunityTab extends ConsumerWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos nuestro nuevo proveedor dedicado
    final communityAsync = ref.watch(communityStreamProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comunidad Oasis', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0E2C74))),
          const SizedBox(height: 8),
          const Text('Conoce a otros misioneros y su recorrido de intercesión global.', style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
          const SizedBox(height: 24),

          // Renderizado Reactivo
          Expanded(
            child: communityAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0E2C74))),
              error: (err, stack) => Center(child: Text('Error al cargar comunidad: $err')),
              data: (List<UserPassport> users) {
                if (users.isEmpty) {
                  return const Center(child: Text('Aún no hay misioneros registrados.'));
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return UserCommunityCard(user: user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// COMPONENTE EXTRAÍDO (SRP): Tarjeta individual del usuario
// =====================================================================
class UserCommunityCard extends StatelessWidget {
  final UserPassport user;

  const UserCommunityCard({super.key, required this.user});

  String _getInitials(String name) {
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.isEmpty) return 'CM';
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return nameParts[0].substring(0, nameParts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final int stampCount = user.stamps.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navegamos a la nueva pantalla pasando el objeto usuario completo
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(user: user),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFDBE1FF),
                child: Text(
                  _getInitials(user.fullName),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E2C74), fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.flag, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        // CORRECCIÓN: Texto más descriptivo
                        Text(
                          'Nacionalidad ${user.nationality}',
                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: stampCount > 0 ? const Color(0xFFFDB65D).withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CORRECCIÓN: Icono cambiado a un "sello de aprobación"
                    Icon(
                      Icons.approval,
                      size: 18,
                      color: stampCount > 0 ? const Color(0xFF865300) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$stampCount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: stampCount > 0 ? const Color(0xFF865300) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}