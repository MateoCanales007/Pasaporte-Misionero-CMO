import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/providers/passport_provider.dart';
import '../mission_detail_screen.dart'; // Importamos la nueva pantalla

class MissionsTab extends ConsumerWidget {
  const MissionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalStampsAsync = ref.watch(globalStampsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Próximas Misiones', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0E2C74))),
          const SizedBox(height: 8),
          const Text('Conoce los proyectos de intercesión programados para nuestros cultos.', style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
          const SizedBox(height: 24),

          globalStampsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error: $e'),
            data: (stamps) {
              final stampList = stamps.entries.toList(); // Usamos entries para tener acceso al ID

              if (stampList.isEmpty) {
                return const Center(child: Text('No hay misiones programadas en este momento.'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stampList.length,
                itemBuilder: (context, index) {
                  final stampId = stampList[index].key;
                  final stamp = stampList[index].value;

                  final bool isActive = stamp['active'] ?? false;
                  final String name = stamp['name'] ?? 'Misión Desconocida';
                  final String isoCode = stamp['isoCode'] ?? 'GLOBAL';
                  final String? imageUrl = stamp['image'];

                  String dateString = 'Fecha por definir';
                  List<dynamic> scheduleList = stamp['schedule'] ?? [];
                  if (scheduleList.isNotEmpty) {
                    DateTime startDate = (scheduleList[0]['start'] as Timestamp).toDate();
                    dateString = "${startDate.day.toString().padLeft(2, '0')} / ${startDate.month.toString().padLeft(2, '0')} / ${startDate.year}";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                    child: InkWell(
                      // --- NAVEGACIÓN A LOS DETALLES ---
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MissionDetailScreen(
                              stampId: stampId,
                              stampData: stamp,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                Image.network(
                                  imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                                )
                              else
                                Container(height: 160, color: const Color(0xFF0E2C74), child: const Center(child: Icon(Icons.public, size: 60, color: Colors.white24))),

                              Positioned(
                                top: 12, right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: isActive ? Colors.green : Colors.black54, borderRadius: BorderRadius.circular(20)),
                                  child: Text(isActive ? 'ACTIVA' : 'PRÓXIMA / FINALIZADA', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74)))),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFFC7A941), borderRadius: BorderRadius.circular(8)),
                                      child: Text(isoCode, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Cita: $dateString', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}