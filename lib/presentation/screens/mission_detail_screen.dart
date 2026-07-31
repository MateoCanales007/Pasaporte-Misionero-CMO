import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Solo functions!

import '../../data/providers/passport_provider.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  final String stampId;
  final Map<String, dynamic> stampData;

  const MissionDetailScreen({
    super.key,
    required this.stampId,
    required this.stampData,
  });

  @override
  ConsumerState<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  late GoogleMapController mapController;
  late LatLng targetLocation;
  late Set<Marker> _markers;

  List<String> _photoRefs = [];
  bool _isLoadingPhotos = true;
  late bool _isActive;

  @override
  void initState() {
    super.initState();

    _isActive = widget.stampData['active'] ?? false;

    if (widget.stampData['location'] is GeoPoint) {
      GeoPoint geo = widget.stampData['location'];
      targetLocation = LatLng(geo.latitude, geo.longitude);
    } else {
      targetLocation = const LatLng(14.6349, -90.5069);
    }

    _markers = {
      Marker(
        markerId: MarkerId(widget.stampId),
        position: targetLocation,
        infoWindow: InfoWindow(title: widget.stampData['name'] ?? 'Misión'),
        icon: BitmapDescriptor.defaultMarker,
      )
    };

    _fetchPhotosLogic();
  }

  Future<void> _toggleMissionStatus(bool status) async {
    if (_isActive == status) return;

    setState(() => _isActive = status);

    try {
      await FirebaseFirestore.instance.collection('stamp').doc(widget.stampId).update({'active': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status ? 'Misión Activada exitosamente.' : 'Misión Desactivada exitosamente.'),
              backgroundColor: status ? Colors.green : Colors.red,
            )
        );
      }
    } catch (e) {
      setState(() => _isActive = !status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  // ✨ MAGIA LIMPIA: Llamamos al backend para que nos dé las referencias
  Future<void> _fetchPhotosLogic() async {
    final String? placeId = widget.stampData['placeId'];

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getPhotoReferences');
      final result = await callable.call(<String, dynamic>{
        'placeId': placeId,
        'lat': targetLocation.latitude,
        'lng': targetLocation.longitude,
      });

      if (result.data['success'] == true) {
        if (mounted) {
          setState(() {
            _photoRefs = List<String>.from(result.data['references']);
            _isLoadingPhotos = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingPhotos = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passportAsync = ref.watch(userPassportProvider);
    final bool isAdmin = passportAsync.value?['isAdmin'] ?? false;

    final stamp = widget.stampData;
    final String name = stamp['name'] ?? 'Misión Desconocida';
    final String isoCode = stamp['isoCode'] ?? 'GLOBAL';
    final String? imageUrl = stamp['image'];

    String startDateStr = 'Por definir';
    String endDateStr = 'Por definir';
    List<dynamic> scheduleList = stamp['schedule'] ?? [];
    if (scheduleList.isNotEmpty) {
      DateTime start = (scheduleList[0]['start'] as Timestamp).toDate();
      DateTime end = (scheduleList[0]['end'] as Timestamp).toDate();
      startDateStr = "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} a las ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
      endDateStr = "${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year} a las ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFF0E2C74),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                isoCode,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 10)]),
              ),
              background: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(color: const Color(0xFF0E2C74), child: const Center(child: Icon(Icons.public, size: 80, color: Colors.white24))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0E2C74))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _isActive ? Colors.green : Colors.grey, borderRadius: BorderRadius.circular(20)),
                        child: Text(_isActive ? 'ACTIVA' : 'INACTIVA', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text('HORARIO DE INTERCESIÓN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 8),

                  ListTile(
                    onTap: isAdmin ? () => _toggleMissionStatus(true) : null,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF4F7FB), child: Icon(Icons.play_arrow, color: Colors.green)),
                    title: const Text('Inicio', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    subtitle: Text(startDateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                  ),
                  ListTile(
                    onTap: isAdmin ? () => _toggleMissionStatus(false) : null,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF4F7FB), child: Icon(Icons.stop, color: Colors.red)),
                    title: const Text('Cierre', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    subtitle: Text(endDateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74))),
                  ),

                  const Divider(height: 40),
                  const Text('UBICACIÓN GEOGRÁFICA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(target: targetLocation, zoom: 11.0),
                      markers: _markers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FOTOS DEL LUGAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                      if (!_isLoadingPhotos && _photoRefs.isNotEmpty)
                        Text('${_photoRefs.length} disponibles', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 120,
                    child: _isLoadingPhotos
                        ? const Center(child: CircularProgressIndicator())
                        : _photoRefs.isEmpty
                        ? const Center(child: Text('No hay fotos disponibles.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoRefs.length,
                      itemBuilder: (context, index) {
                        return CloudPhotoWidget(photoReference: _photoRefs[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CloudPhotoWidget extends StatefulWidget {
  final String photoReference;

  const CloudPhotoWidget({super.key, required this.photoReference});

  @override
  State<CloudPhotoWidget> createState() => _CloudPhotoWidgetState();
}

class _CloudPhotoWidgetState extends State<CloudPhotoWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getMissionPlacePhoto');
      final result = await callable.call(<String, dynamic>{
        'photoReference': widget.photoReference,
      });

      if (result.data['success'] == true) {
        final String base64String = result.data['imageBase64'];
        if (mounted) {
          setState(() {
            _imageBytes = base64Decode(base64String);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _openFullScreen(BuildContext context) {
    if (_imageBytes == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_imageBytes!), // Dibuja desde bytes
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError || _imageBytes == null
            ? const Icon(Icons.broken_image, color: Colors.grey)
            : Image.memory(_imageBytes!, fit: BoxFit.cover),
      ),
    );
  }
}