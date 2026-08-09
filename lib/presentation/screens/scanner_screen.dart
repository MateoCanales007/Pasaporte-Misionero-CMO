import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Controlador de la cámara del escáner
  late MobileScannerController cameraController;

  // Candado para evitar que el escáner lea el mismo código 10 veces por segundo
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  // 🧠 LÓGICA PRINCIPAL: Cuando la cámara detecta un código QR
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // Si ya estamos validando un código, ignoramos los demás

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue; // Este será el stampId (ej: "ec612cb9-...")
    if (qrData == null) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión activa.');

      // 1. Buscar los metadatos del Sello en Firestore
      final stampDoc = await FirebaseFirestore.instance.collection('stamp').doc(qrData).get();

      if (!stampDoc.exists) {
        _showResultDialog('Sello no encontrado', 'Este código QR no pertenece al sistema del CMO.', isError: true);
        return;
      }

      final stampData = stampDoc.data()!;
      final String countryName = stampData['name'] ?? 'Misión';

      // 2. Validar que el sello esté activo globalmente
      if (stampData['active'] != true) {
        _showResultDialog('Sello Inactivo', 'El sello para $countryName ya no está disponible.', isError: true);
        return;
      }

      // 3. Validar el Horario (Schedule) de la colección de tu compañero
      List<dynamic> schedules = stampData['schedule'] ?? [];
      bool isTimeValid = false;
      DateTime now = DateTime.now();

      for (var schedule in schedules) {
        DateTime start = (schedule['start'] as Timestamp).toDate();
        DateTime end = (schedule['end'] as Timestamp).toDate();

        // Verificamos si la hora actual está dentro del rango permitido
        if (now.isAfter(start) && now.isBefore(end)) {
          isTimeValid = true;
          break; // Con un horario válido que coincida, es suficiente
        }
      }

      if (!isTimeValid) {
        _showResultDialog('Fuera de Horario', 'El sello para $countryName no está habilitado en este momento.', isError: true);
        return;
      }

      // 4. Escribir en el Pasaporte del Usuario (user_passport)
      final passportRef = FirebaseFirestore.instance.collection('user_passport').doc(user.uid);
      final passportSnap = await passportRef.get();

      if (passportSnap.exists) {
        List<dynamic> userStamps = passportSnap.data()!['stamps'] ?? [];

        // Evitar que escaneen el mismo sello dos veces
        bool alreadyHasStamp = userStamps.any((stamp) => stamp['stampId'] == qrData);
        if (alreadyHasStamp) {
          _showResultDialog('Sello Duplicado', 'Ya tienes el sello de $countryName en tu pasaporte.', isError: true);
          return;
        }

        // ¡EL GUARDADO FINAL! Usamos arrayUnion para agregar a la lista sin borrar lo anterior
        await passportRef.update({
          'stamps': FieldValue.arrayUnion([
            {
              'stampId': qrData,
              'dateObtained': Timestamp.now(), // Fecha exacta del escaneo
            }
          ])
        });

        _showResultDialog('¡Sello Obtenido!', 'El sello de $countryName ha sido agregado a tu pasaporte virtual con éxito.', isError: false);
      }

    } catch (e) {
      _showResultDialog('Error', 'Ocurrió un error al procesar el código: $e', isError: true);
    }
  }

  // Interfaz de Diálogo para mostrar éxito o error
  void _showResultDialog(String title, String message, {required bool isError}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle,
                color: isError ? Colors.red : Colors.green, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E2C74),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el diálogo
              if (isError) {
                setState(() => _isProcessing = false); // Permite intentar de nuevo si falló
              } else {
                Navigator.of(context).pop(); // Si fue éxito, regresa a la pantalla del Pasaporte
              }
            },
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Escanear Sello Oficial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. La Cámara
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // 2. Filtro oscuro con un agujero transparente en el medio
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFFFDB65D), // Dorado
                borderRadius: 12,
                borderLength: 35,
                borderWidth: 8,
                cutOutSize: MediaQuery.of(context).size.width * 0.75, // Tamaño del cuadro
              ),
            ),
          ),

          // 3. Texto de ayuda
          Positioned(
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Text(
                'Apunta al código QR de la misión',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          // Indicador de carga si está procesando
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFDB65D)),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// CLASE AUXILIAR: Dibuja el marco con la mirilla transparente
// -------------------------------------------------------------
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.65),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..fillType = PathFillType.evenOdd..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }
    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > cutOutSize / 2 + borderWidthSize ? borderWidthSize / 2 : borderLength;
    final _cutOutSize = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)), boxPaint)
      ..restore();

    canvas.drawPath(
      Path()
      // Esquina superior izquierda
        ..moveTo(cutOutRect.left, cutOutRect.top + _borderLength)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + _borderLength, cutOutRect.top)
      // Esquina superior derecha
        ..moveTo(cutOutRect.right - _borderLength, cutOutRect.top)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + _borderLength)
      // Esquina inferior derecha
        ..moveTo(cutOutRect.right, cutOutRect.bottom - _borderLength)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - _borderLength, cutOutRect.bottom)
      // Esquina inferior izquierda
        ..moveTo(cutOutRect.left + _borderLength, cutOutRect.bottom)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - _borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}