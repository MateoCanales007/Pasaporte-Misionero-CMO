import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/models/mission.dart';

/// Construye el mapa. Se inyecta para poder reemplazarlo en pruebas, donde los
/// mapas nativos no están disponibles.
typedef MapViewBuilder =
    Widget Function({GeoLocation? marker, required GeoLocation center, double zoom, ValueChanged<GeoLocation>? onTap});

final mapViewBuilderProvider = Provider<MapViewBuilder>((ref) => _buildGoogleMap);

Widget _buildGoogleMap({
  GeoLocation? marker,
  required GeoLocation center,
  double zoom = 12,
  ValueChanged<GeoLocation>? onTap,
}) => AppGoogleMap(marker: marker, center: center, zoom: zoom, onTap: onTap);

/// Centro por defecto: San Salvador.
const defaultMapCenter = GeoLocation(13.6929, -89.2182);

class AppGoogleMap extends StatefulWidget {
  const AppGoogleMap({super.key, this.marker, required this.center, this.zoom = 12, this.onTap});

  final GeoLocation? marker;
  final GeoLocation center;
  final double zoom;
  final ValueChanged<GeoLocation>? onTap;

  @override
  State<AppGoogleMap> createState() => _AppGoogleMapState();
}

class _AppGoogleMapState extends State<AppGoogleMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant AppGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final marker = widget.marker;
    if (marker != null && marker != oldWidget.marker) {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(marker.latitude, marker.longitude), 16));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marker = widget.marker;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng((marker ?? widget.center).latitude, (marker ?? widget.center).longitude),
        zoom: marker != null ? 15 : widget.zoom,
      ),
      onMapCreated: (controller) => _controller = controller,
      onTap: widget.onTap == null ? null : (latLng) => widget.onTap!(GeoLocation(latLng.latitude, latLng.longitude)),
      markers: {
        if (marker != null)
          Marker(markerId: const MarkerId('selected'), position: LatLng(marker.latitude, marker.longitude)),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }
}
