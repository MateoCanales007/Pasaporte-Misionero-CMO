import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/providers/passport_provider.dart';
import '../widgets/custom_app_bar.dart';
import 'tabs/passport_tab.dart';
import 'tabs/missions_tab.dart';
import 'tabs/community_tab.dart';
import 'scanner_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _showAdminQR(BuildContext context, AsyncValue<Map<String, dynamic>> globalStampsAsync) {
    globalStampsAsync.whenData((stamps) {
      String? activeStampId;
      String? activeStampName;
      DateTime now = DateTime.now();

      for (var entry in stamps.entries) {
        var stampData = entry.value;
        if (stampData['active'] == true) {
          List<dynamic> schedules = stampData['schedule'] ?? [];
          for (var schedule in schedules) {
            DateTime start = (schedule['start'] as Timestamp).toDate();
            DateTime end = (schedule['end'] as Timestamp).toDate();
            if (now.isAfter(start) && now.isBefore(end)) {
              activeStampId = entry.key;
              activeStampName = stampData['name'];
              break;
            }
          }
        }
        if (activeStampId != null) break;
      }

      if (activeStampId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ningún sello activo programado para esta hora.'), backgroundColor: Colors.red));
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Sello Activo:\n$activeStampName', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(width: 250, height: 250, child: Center(child: QrImageView(data: activeStampId!, version: QrVersions.auto, size: 250.0, backgroundColor: Colors.white))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR', style: TextStyle(fontWeight: FontWeight.bold)))],
        ),
      );
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return const PassportTab();
      case 1: return const MissionsTab();
      case 2: return const CommunityTab();
      default: return const PassportTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final passportAsync = ref.watch(userPassportProvider);
    final globalStampsAsync = ref.watch(globalStampsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: const CustomAppBar(),
      body: _buildBody(),
      floatingActionButton: _currentIndex != 2 ? passportAsync.whenData((data) {
        final bool canShowQR = data?['canShowQR'] ?? false;

        return canShowQR
            ? FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0E2C74),
          elevation: 6,
          icon: const Icon(Icons.qr_code, color: Colors.white, size: 24),
          label: const Text('MOSTRAR QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () => _showAdminQR(context, globalStampsAsync),
        )
            : FloatingActionButton.extended(
          backgroundColor: const Color(0xFFFDB65D),
          elevation: 6,
          icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2B1700), size: 24),
          label: const Text('ESCANEAR SELLO', style: TextStyle(color: Color(0xFF2B1700), fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen())),
        );
      }).value : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0E2C74),
        unselectedItemColor: Colors.blueGrey[300],
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Pasaporte'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Misiones'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Comunidad'),
        ],
      ),
    );
  }
}