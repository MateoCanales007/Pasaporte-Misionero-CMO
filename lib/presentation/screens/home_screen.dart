import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/providers/passport_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Variable de estado: Controla si el pasaporte está cerrado (pequeño) o abierto (pantalla completa)
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final passportAsync = ref.watch(userPassportProvider);
    final globalStampsAsync = ref.watch(globalStampsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2C74),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/images/cmo.png', height: 35, errorBuilder: (context, _, __) {
              return const Icon(Icons.public, color: Colors.white);
            }),
            const SizedBox(width: 10),
            const Text(
              'Pasaporte Virtual CMO',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al sincronizar bitácora: $err')),
        data: (passportData) {
          if (passportData == null) return const Center(child: Text('No se encontró una sesión activa de misionero.'));

          final List<dynamic> userStamps = passportData['stamps'] ?? [];
          final String fullName = passportData['fullName'] ?? 'MISIONERO OASIS';
          final String passportNumber = passportData['passportNumber'] ?? 'PM-2026-0000';

          final mrzName = fullName.toUpperCase().replaceAll(' ', '<').padRight(22, '<').substring(0, 22);
          final mrzPass = passportNumber.replaceAll('-', '').padRight(12, '<');

          return Stack(
            children: [
              // Texto de ayuda en el fondo (solo visible cuando el pasaporte está cerrado)
              if (!_isOpen)
                const Align(
                  alignment: Alignment(0, 0.75), // Ubicado en la parte inferior de la pantalla
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'TOCA EL PASAPORTE PARA ABRIRLO',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),

              // =========================================================
              // EL PASAPORTE ANIMADO (Efecto Zoom / Scale)
              // =========================================================
              AnimatedAlign(
                alignment: Alignment.center,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                child: GestureDetector(
                  onTap: () {
                    // Si está cerrado, al tocarlo se abre
                    if (!_isOpen) setState(() => _isOpen = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    // AQUÍ ESTÁ LA MAGIA: Intercambia el tamaño estático por el tamaño total de la pantalla
                    width: _isOpen ? MediaQuery.of(context).size.width : 280,
                    height: _isOpen ? MediaQuery.of(context).size.height : 420,
                    // Elimina los márgenes cuando se expande para ocupar todo el espacio
                    margin: _isOpen ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      // Transición de esquinas redondeadas a esquinas rectas al expandirse
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
                      // Desaparecen las sombras cuando cubre toda la pantalla
                      boxShadow: _isOpen ? [] : [
                        BoxShadow(color: const Color(0xFF0E2C74).withOpacity(0.4), blurRadius: 15, offset: const Offset(10, 10)),
                        const BoxShadow(color: Colors.white, blurRadius: 0, offset: Offset(4, 0)),
                        const BoxShadow(color: Color(0xFFE0E0E0), blurRadius: 0, offset: Offset(5, 0)),
                      ],
                    ),
                    // Transición suave entre el diseño de la portada y las páginas internas
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFDB65D),
        elevation: 6,
        icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2B1700), size: 24),
        label: const Text('ESCANEAR SELLO', style: TextStyle(color: Color(0xFF2B1700), fontWeight: FontWeight.bold)),
        onPressed: () {
          print("Fase 3: Ejecutar mobile_scanner");
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0E2C74),
        unselectedItemColor: Colors.blueGrey[300],
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Pasaporte'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Misiones'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Comunidad'),
        ],
      ),
    );
  }

  // ============================================================
  // DISEÑO 1: LA PORTADA (ESTADO CERRADO)
  // Utiliza el diseño exacto que tú aprobaste
  // ============================================================
  Widget _buildCover(String fullName, String mrzName, String mrzPass) {
    return Center(
      key: const ValueKey('cover'),
      child: SizedBox(
        width: 280,
        height: 420,
        child: Stack(
          children: [
            Positioned(
              left: 12, top: 20, bottom: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(12, (index) => Container(width: 2, height: 12, color: Colors.white.withOpacity(0.15))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 35, right: 20, top: 40, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('CENTRO MISIONERO\nOASIS', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC7A941), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 30),
                  Image.asset('assets/images/logo.png', height: 85, color: const Color(0xFFC7A941), errorBuilder: (c, _, __) => const Icon(Icons.public, color: Color(0xFFC7A941), size: 85)),
                  const SizedBox(height: 30),
                  const Text('PASAPORTE', style: TextStyle(color: Color(0xFFC7A941), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6)),
                  const Spacer(),
                  Text(fullName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 5),
                  Text('MISIONERO ACTIVO', style: TextStyle(color: const Color(0xFFC7A941).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),
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

  // ============================================================
  // DISEÑO 2: LAS PÁGINAS INTERNAS (ESTADO ABIERTO)
  // Se revela una vez que la animación abarca la pantalla
  // ============================================================
  Widget _buildInsidePages(String fullName, List<dynamic> userStamps, AsyncValue<Map<String, dynamic>> globalStampsAsync) {
    return Container(
      key: const ValueKey('inside'),
      // El margen permite que se siga viendo un "borde azul" del cuero como fondo
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC), // Color que simula hoja de papel real
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Barra superior de la página con el botón para "cerrar" la libreta
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.grey, size: 18),
                  onPressed: () => setState(() => _isOpen = false), // Cierra el pasaporte
                ),
                const Text('PÁGINA DE SELLOS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                const SizedBox(width: 48), // Balance visual para centrar el texto
              ],
            ),
          ),

          // Contenido principal de tu bitácora
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
                          final String countryName = catalogInfo?['isoCode'] ?? 'Nación';
                          final String infoDescription = catalogInfo?['name'] ?? 'Proyecto Misionero';

                          final dateStr = "${dateObtainedValue.toDate().day}/${dateObtainedValue.toDate().month}/${dateObtainedValue.toDate().year}";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: Colors.white,
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDBE1FF),
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                  ),
                                  child: const Center(child: Icon(Icons.flight_land, size: 30, color: Color(0xFF0E2C74))),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(countryName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                                          const Icon(Icons.verified, color: Color(0xFFC7A941)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(infoDescription, style: const TextStyle(fontSize: 14, color: Color(0xFF865300), fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('SELLO OFICIAL', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
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