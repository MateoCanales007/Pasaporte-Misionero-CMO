import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/providers/passport_provider.dart';

class PassportTab extends ConsumerStatefulWidget {
  const PassportTab({super.key});

  @override
  ConsumerState<PassportTab> createState() => _PassportTabState();
}

class _PassportTabState extends ConsumerState<PassportTab> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final passportAsync = ref.watch(userPassportProvider);
    final globalStampsAsync = ref.watch(globalStampsProvider);

    return passportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (passportData) {
        if (passportData == null) return const Center(child: Text('Sin sesión activa'));

        final List<dynamic> userStamps = passportData['stamps'] ?? [];
        final String fullName = passportData['fullName'] ?? 'MISIONERO OASIS';
        final String passportNumber = passportData['passportNumber'] ?? 'PM-2026-0000';

        final mrzName = fullName.toUpperCase().replaceAll(' ', '<').padRight(22, '<').substring(0, 22);
        final mrzPass = passportNumber.replaceAll('-', '').padRight(12, '<');

        return Stack(
          children: [
            if (!_isOpen)
              const Align(
                alignment: Alignment(0, 0.75),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('TOCA EL PASAPORTE PARA ABRIRLO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),

            AnimatedAlign(
              alignment: Alignment.center,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: GestureDetector(
                onTap: () {
                  if (!_isOpen) setState(() => _isOpen = true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  width: _isOpen ? MediaQuery.of(context).size.width : 280,
                  // TAMAÑO ORIGINAL: Mantenemos la altura oficial de 420
                  height: _isOpen ? MediaQuery.of(context).size.height : 420,
                  margin: _isOpen ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_isOpen ? 0 : 6),
                      bottomLeft: Radius.circular(_isOpen ? 0 : 6),
                      topRight: Radius.circular(_isOpen ? 0 : 24),
                      bottomRight: Radius.circular(_isOpen ? 0 : 24),
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF071840), Color(0xFF0E2C74), Color(0xFF16378A)],
                      stops: [0.0, 0.15, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: _isOpen ? [] : [
                      BoxShadow(color: const Color(0xFF0E2C74).withOpacity(0.4), blurRadius: 15, offset: const Offset(10, 10)),
                      const BoxShadow(color: Colors.white, blurRadius: 0, offset: Offset(4, 0)),
                      const BoxShadow(color: Color(0xFFE0E0E0), blurRadius: 0, offset: Offset(5, 0)),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _isOpen
                        ? _buildInsidePages(fullName, userStamps, globalStampsAsync)
                        : _buildCover(fullName, mrzName, mrzPass),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- DISEÑO DE PORTADA ACTUALIZADO ---
  Widget _buildCover(String fullName, String mrzName, String mrzPass) {
    return Center(
      key: const ValueKey('cover'),
      child: SizedBox(
        width: 280,
        height: 420, // Altura base original
        child: Stack(
          children: [
            // Detalles del lomo (Las costuras)
            Positioned(
              left: 12, top: 20, bottom: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(12, (index) => Container(width: 2, height: 12, color: Colors.white.withOpacity(0.15))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 35, right: 20, top: 35, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. TÍTULO ACTUALIZADO: Combinando "Pasaporte" y "Centro Misionero Oasis"
                  const Text(
                      'PASAPORTE\nCENTRO MISIONERO OASIS',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFC7A941), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, height: 1.4)
                  ),

                  const SizedBox(height: 25),

                  // 2. ESCUDO PROTAGONISTA: Aumentado de 85 a 140 píxeles
                  Image.asset(
                      'assets/images/cmo.png',
                      height: 180,
                      color: const Color(0xFFC7A941),
                      errorBuilder: (c, _, __) => const Icon(Icons.public, color: Color(0xFFC7A941), size: 180)
                  ),

                  // (Se eliminó la palabra "PASAPORTE" gigante de aquí en medio)

                  // El Spacer() hace de "resorte", empujando lo de arriba hacia arriba y lo de abajo hacia abajo
                  const Spacer(),

                  // DATOS DEL USUARIO
                  Text(fullName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 5),
                  Text('MISIONERO ACTIVO', style: TextStyle(color: const Color(0xFFC7A941).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),

                  // CÓDIGO MRZ
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('P<CMO<$mrzName', maxLines: 1, style: const TextStyle(fontFamily: 'Courier', color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                        Text('$mrzPass<4SLV<<<<<<<<<<<', maxLines: 1, style: const TextStyle(fontFamily: 'Courier', color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LAS PÁGINAS INTERNAS SE MANTIENEN IGUAL ---
  Widget _buildInsidePages(String fullName, List<dynamic> userStamps, AsyncValue<Map<String, dynamic>> globalStampsAsync) {
    return Container(
      key: const ValueKey('inside'),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFC), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.grey, size: 18), onPressed: () => setState(() => _isOpen = false)),
                const Text('PÁGINA DE SELLOS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Bienvenido, $fullName!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                  const SizedBox(height: 8),
                  const Text('Revisa tus visitas y el avance de tu viaje espiritual de intercesión global.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 25),
                  globalStampsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Container(),
                    data: (stampCatalog) {
                      if (userStamps.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Column(
                              children: [
                                Icon(Icons.flight_takeoff, size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 15),
                                const Text('Tu pasaporte está nuevo.\n¡Escanea tu primer sello en el culto!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: userStamps.length,
                        itemBuilder: (context, index) {
                          final currentStamp = userStamps[index];
                          final String stampId = currentStamp['stampId'] ?? '';
                          final Timestamp dateObtainedValue = currentStamp['dateObtained'] ?? Timestamp.now();

                          final catalogInfo = stampCatalog[stampId];
                          final String stampName = catalogInfo?['name'] ?? 'Proyecto Misionero';
                          final String? stampImageUrl = catalogInfo?['image'];
                          final dateStr = "${dateObtainedValue.toDate().day}/${dateObtainedValue.toDate().month}/${dateObtainedValue.toDate().year}";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.white, elevation: 2, shadowColor: Colors.black.withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: stampImageUrl != null && stampImageUrl.isNotEmpty
                                        ? Image.network(stampImageUrl, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (context, error, stack) => Container(width: 64, height: 64, color: const Color(0xFFDBE1FF), child: const Icon(Icons.flight_land, size: 28, color: Color(0xFF0E2C74))))
                                        : Container(width: 64, height: 64, color: const Color(0xFFDBE1FF), child: const Icon(Icons.flight_land, size: 28, color: Color(0xFF0E2C74))),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(stampName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                                        const SizedBox(height: 4),
                                        Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}