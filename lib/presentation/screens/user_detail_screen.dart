import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_passport.dart';
import '../../data/providers/passport_provider.dart';
import '../../data/providers/cell_provider.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final UserPassport user;
  const UserDetailScreen({super.key, required this.user});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  late bool _canShowQR;

  @override
  void initState() {
    super.initState();
    _canShowQR = widget.user.canShowQR;
  }

  String _getInitials(String name) {
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.isEmpty) return 'CM';
    if (nameParts.length > 1) return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    return nameParts[0].substring(0, nameParts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final globalStampsAsync = ref.watch(globalStampsProvider);
    final cellsAsync = ref.watch(cellsStreamProvider);

    final currentUserAsync = ref.watch(userPassportProvider);
    final bool isLoggedAdmin = currentUserAsync.value?['isAdmin'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2C74),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Perfil de Misionero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0E2C74),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50, backgroundColor: const Color(0xFFC7A941),
                    child: CircleAvatar(radius: 46, backgroundColor: Colors.white, child: Text(_getInitials(widget.user.fullName), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74)))),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flag, color: Color(0xFFC7A941), size: 16),
                      const SizedBox(width: 4),
                      Text('Nacionalidad ${widget.user.nationality}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  cellsAsync.when(
                    loading: () => const SizedBox(),
                    error: (e, s) => const SizedBox(),
                    data: (cells) {
                      final cellMap = cells.firstWhere((c) => c['id'] == widget.user.cellId, orElse: () => {'name': 'Célula Desconocida'});
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group_work, color: Color(0xFFC7A941), size: 16),
                          const SizedBox(width: 4),
                          Text('Célula: ${cellMap['name']}', style: const TextStyle(color: Colors.white70)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            if (isLoggedAdmin)
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7A941).withOpacity(0.5)),
                ),
                child: SwitchListTile(
                  activeColor: const Color(0xFF0E2C74),
                  title: const Text('Rol: Personal de Apoyo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                  subtitle: const Text('Permite a este usuario generar el código QR de las misiones.', style: TextStyle(fontSize: 12)),
                  value: _canShowQR,
                  onChanged: (bool value) async {
                    setState(() => _canShowQR = value);
                    await FirebaseFirestore.instance.collection('user_passport').doc(widget.user.id).update({'canShowQR': value});
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permisos actualizados para ${widget.user.fullName}')));
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.approval, color: Color(0xFF865300)),
                      const SizedBox(width: 8),
                      Text('Sellos Obtenidos (${widget.user.stamps.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (widget.user.stamps.isEmpty)
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Column(
                        children: [
                          Icon(Icons.flight_takeoff, size: 48, color: Colors.black12),
                          SizedBox(height: 12),
                          Text('Aún no ha escaneado sellos misioneros.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    globalStampsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Error al cargar sellos: $e'),
                      data: (stampCatalog) {
                        return ListView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.user.stamps.length,
                          itemBuilder: (context, index) {
                            final currentStamp = widget.user.stamps[index];
                            final String stampId = currentStamp['stampId'] ?? '';
                            final Timestamp dateObtainedValue = currentStamp['dateObtained'] ?? Timestamp.now();
                            final catalogInfo = stampCatalog[stampId];
                            final String stampName = catalogInfo?['name'] ?? 'Proyecto Misionero';
                            final String? stampImageUrl = catalogInfo?['image'];
                            final dateStr = "${dateObtainedValue.toDate().day}/${dateObtainedValue.toDate().month}/${dateObtainedValue.toDate().year}";

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Colors.white, elevation: 2, shadowColor: Colors.black.withOpacity(0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: stampImageUrl != null && stampImageUrl.isNotEmpty
                                          ? Image.network(stampImageUrl, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 64, height: 64, color: const Color(0xFFDBE1FF), child: const Icon(Icons.flight_land, size: 28, color: Color(0xFF0E2C74))))
                                          : Container(width: 64, height: 64, color: const Color(0xFFDBE1FF), child: const Icon(Icons.flight_land, size: 28, color: Color(0xFF0E2C74))),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(stampName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                                          const SizedBox(height: 4),
                                          Text('Fecha: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.verified, color: Color(0xFFC7A941), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}