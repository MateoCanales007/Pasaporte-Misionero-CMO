import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart'; // IMPORTANTE: Agregamos las funciones

class CreateStampScreen extends StatefulWidget {
  const CreateStampScreen({super.key});

  @override
  State<CreateStampScreen> createState() => _CreateStampScreenState();
}

class _CreateStampScreenState extends State<CreateStampScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _isoController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedPlaceId;
  Set<Marker> _markers = {};

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _endTime = TimeOfDay.now();

  bool _isActive = true;
  bool _isLoading = false;

  // ✨ MAGIA 1: BUSCAMOS LUGARES USANDO FIREBASE FUNCTIONS
  Future<Iterable<Map<String, dynamic>>> _searchPlacesAutocomplete(String query) async {
    if (query.isEmpty) return const Iterable<Map<String, dynamic>>.empty();

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('searchPlaces');
      final result = await callable.call({'query': query});

      if (result.data['success'] == true) {
        final List predictions = result.data['predictions'];
        return predictions.map((p) => {
          'description': p['description'],
          'place_id': p['place_id'],
        });
      }
    } catch (e) {
      debugPrint('Error en Autocomplete (Functions): $e');
    }
    return const Iterable<Map<String, dynamic>>.empty();
  }

  // ✨ MAGIA 2: OBTENEMOS COORDENADAS USANDO FIREBASE FUNCTIONS
  Future<void> _getPlaceDetailsAndMoveMap(String placeId) async {
    setState(() => _isLoading = true);

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getPlaceDetails');
      final result = await callable.call({'placeId': placeId});

      if (result.data['success'] == true) {
        final location = result.data['location'];
        final latLng = LatLng(location['lat'], location['lng']);

        setState(() {
          _selectedLocation = latLng;
          _selectedPlaceId = placeId;
          _markers = {
            Marker(
              markerId: const MarkerId('selected_location'),
              position: latLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            )
          };
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
      }
    } catch (e) {
      debugPrint('Error obteniendo detalles (Functions): $e');
    }
    setState(() => _isLoading = false);
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedPlaceId = null;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        )
      };
    });
  }

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime : _endTime,
      );
      if (pickedTime != null) {
        setState(() {
          if (isStart) {
            _startDate = pickedDate;
            _startTime = pickedTime;
          } else {
            _endDate = pickedDate;
            _endTime = pickedTime;
          }
        });
      }
    }
  }

  void _saveStamp() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debe seleccionar una ubicación en el mapa o buscador.'))
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        DateTime finalStart = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
        DateTime finalEnd = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);

        final Map<String, dynamic> stampData = {
          'active': _isActive,
          'image': _imageController.text.trim(),
          'isoCode': _isoController.text.trim().toUpperCase(),
          'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
          'name': _nameController.text.trim(),
          'schedule': [
            {
              'start': Timestamp.fromDate(finalStart),
              'end': Timestamp.fromDate(finalEnd),
            }
          ]
        };

        if (_selectedPlaceId != null) {
          stampData['placeId'] = _selectedPlaceId;
        }

        await FirebaseFirestore.instance.collection('stamp').add(stampData);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Misión generada y almacenada correctamente.')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar la transacción: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Generar Misión Oficial (Sello)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0E2C74),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0E2C74)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Denominación de la Misión'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: TextFormField(
                          controller: _isoController,
                          decoration: const InputDecoration(labelText: 'ISO Code'),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null
                      )
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      flex: 2,
                      child: TextFormField(
                          controller: _imageController,
                          decoration: const InputDecoration(labelText: 'URL de Imágen'),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null
                      )
                  ),
                ],
              ),
              const SizedBox(height: 30),

              const Text('Buscador de Ubicaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0E2C74))),
              const SizedBox(height: 8),

              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return _searchPlacesAutocomplete(textEditingValue.text);
                },
                displayStringForOption: (option) => option['description'] ?? '',
                onSelected: (option) {
                  FocusScope.of(context).unfocus();
                  _getPlaceDetailsAndMoveMap(option['place_id']);
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Ej: Iglesia, Monumento, Ciudad...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF0E2C74)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 48,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.grey),
                              title: Text(option['description'], style: const TextStyle(fontSize: 14)),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Container(
                height: 300,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(14.6349, -90.5069),
                    zoom: 5.0,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _onMapTapped,
                  markers: _markers,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
              if (_selectedLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      'Coordenadas fijadas: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                  ),
                ),
              const SizedBox(height: 30),

              const Text('Parámetros de Intercesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0E2C74))),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Ventana de Apertura'),
                subtitle: Text('${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year} ${_startTime.format(context)}'),
                trailing: ElevatedButton(onPressed: () => _selectDateTime(true), child: const Text('Ajustar')),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop, color: Colors.red),
                title: const Text('Ventana de Clausura'),
                subtitle: Text('${_endDate.day.toString().padLeft(2, '0')}/${_endDate.month.toString().padLeft(2, '0')}/${_endDate.year} ${_endTime.format(context)}'),
                trailing: ElevatedButton(onPressed: () => _selectDateTime(false), child: const Text('Ajustar')),
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visibilidad Global'),
                subtitle: const Text('Determina si el sello está habilitado para su validación.'),
                value: _isActive,
                activeColor: const Color(0xFF0E2C74),
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E2C74)),
                  onPressed: _saveStamp,
                  child: const Text('PERSISTIR EN FIRESTORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}