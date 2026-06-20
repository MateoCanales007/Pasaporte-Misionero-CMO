import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/providers/cell_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedNationality;
  String? _selectedCellId;
  bool _isLoading = false;

  // Lista estática de nacionalidades sugeridas (No gasta base de datos)
  final List<String> _nationalities = [
    'Salvadoreña', 'Guatemalteca', 'Hondureña', 'Mexicana',
    'Estadounidense', 'Colombiana', 'Costarricense', 'Nicaragüense', 'Otra'
  ];

  // Dispara el Calendario Nativo del Sistema Operativo
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0E2C74),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0E2C74)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() => _isLoading = true);

      try {
        await AuthRepository().createPassport(
          fullName: _nameController.text.trim(),
          dateOfBirth: _selectedDate!,
          nationality: _selectedNationality!,
          cellId: _selectedCellId!,
        );
        // ¡LA MAGIA DE RIVERPOD! Al crear el documento en Firebase, el `SessionRouter`
        // lo detectará automáticamente y te cambiará al `HomeScreen` sin hacer Navigator.push.
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona tu fecha de nacimiento')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellsAsync = ref.watch(cellsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Completa tu Pasaporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0E2C74),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.badge, size: 60, color: Color(0xFFC7A941)),
              const SizedBox(height: 20),
              const Text(
                'Último paso',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0E2C74)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa tus datos reales para generar la Zona de Lectura de tu pasaporte internacional.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // 1. INPUT DE TEXTO: NOMBRE COMPLETO
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // 2. INPUT DE CALENDARIO NATIVO
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de Nacimiento',
                    prefixIcon: const Icon(Icons.calendar_month),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Selecciona una fecha'
                        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                    style: TextStyle(color: _selectedDate == null ? Colors.grey[600] : Colors.black87, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. SELECT DINÁMICO: NACIONALIDAD (Lista Estática)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Nacionalidad',
                  prefixIcon: const Icon(Icons.flag),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _nationalities.map((String nat) {
                  return DropdownMenuItem(value: nat, child: Text(nat));
                }).toList(),
                onChanged: (val) => setState(() => _selectedNationality = val),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // 4. SELECT DINÁMICO: CÉLULAS (Directo de Firestore NoSQL)
              cellsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error cargando células: $e'),
                data: (cells) {
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Célula a la que perteneces',
                      prefixIcon: const Icon(Icons.group_work),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: cells.map((cell) {
                      return DropdownMenuItem(value: cell['id'], child: Text(cell['name']!));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCellId = val),
                    validator: (v) => v == null ? 'Requerido' : null,
                  );
                },
              ),
              const SizedBox(height: 40),

              // BOTÓN DE GUARDAR
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB65D), // Color dorado/naranja
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveProfile,
                child: const Text('GENERAR PASAPORTE', style: TextStyle(color: Color(0xFF2B1700), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}