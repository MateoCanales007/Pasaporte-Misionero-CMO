import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final TextEditingController _customNationalityController = TextEditingController();
  final TextEditingController _customCellController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedNationality;
  String? _selectedCellId;

  bool _isCustomNationality = false;
  bool _isCustomCell = false;
  bool _isLoading = false;

  final List<String> _nationalities = [
    'Salvadoreña', 'Guatemalteca', 'Hondureña', 'Mexicana',
    'Estadounidense', 'Colombiana', 'Costarricense', 'Nicaragüense', 'Otra'
  ];

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

      final String finalNationality = _isCustomNationality ? _customNationalityController.text.trim() : _selectedNationality!;
      final String finalCellId = _isCustomCell ? _customCellController.text.trim() : _selectedCellId!;

      try {
        await AuthRepository().createPassport(
          fullName: _nameController.text.trim(),
          dateOfBirth: _selectedDate!,
          nationality: finalNationality,
          cellId: finalCellId,
        );
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
      // ✨ Fondo devuelto a un color claro
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Completa tu Pasaporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0E2C74),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0E2C74)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF0E2C74)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // ✨ FECHA DE NACIMIENTO COMO PLACEHOLDER
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    // Quitamos el labelText para que no flote hacia arriba
                    prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0E2C74)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Fecha de Nacimiento' // Actúa como Placeholder
                        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                    style: TextStyle(color: _selectedDate == null ? Colors.grey[600] : Colors.black87, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Nacionalidad',
                  prefixIcon: const Icon(Icons.flag, color: Color(0xFF0E2C74)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _nationalities.map((String nat) {
                  return DropdownMenuItem(value: nat, child: Text(nat));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedNationality = val;
                    _isCustomNationality = (val == 'Otra');
                  });
                },
                validator: (v) => v == null ? 'Requerido' : null,
              ),

              if (_isCustomNationality) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customNationalityController,
                  decoration: InputDecoration(
                    labelText: 'Escribe tu Nacionalidad',
                    prefixIcon: const Icon(Icons.edit, color: Color(0xFF0E2C74)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v!.isEmpty ? 'Escribe tu nacionalidad' : null,
                ),
              ],
              const SizedBox(height: 16),

              cellsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0E2C74))),
                error: (e, s) => Text('Error cargando células: $e', style: const TextStyle(color: Colors.red)),
                data: (cells) {
                  List<DropdownMenuItem<String>> cellItems = cells.map((cell) {
                    return DropdownMenuItem<String>(value: cell['id'], child: Text(cell['name']!));
                  }).toList();
                  cellItems.add(const DropdownMenuItem(value: 'otra', child: Text('Otra / Aún no tengo')));

                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Célula a la que perteneces',
                      prefixIcon: const Icon(Icons.group_work, color: Color(0xFF0E2C74)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: cellItems,
                    onChanged: (val) {
                      setState(() {
                        _selectedCellId = val;
                        _isCustomCell = (val == 'otra');
                      });
                    },
                    validator: (v) => v == null ? 'Requerido' : null,
                  );
                },
              ),

              if (_isCustomCell) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customCellController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la célula / o escribe "Ninguna"',
                    prefixIcon: const Icon(Icons.edit, color: Color(0xFF0E2C74)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v!.isEmpty ? 'Por favor escribe un valor' : null,
                ),
              ],
              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E2C74),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveProfile,
                child: const Text('GENERAR PASAPORTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}