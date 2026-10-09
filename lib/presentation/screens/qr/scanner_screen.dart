import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/pending_redemptions_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import 'redemption_result_view.dart';
import 'scanner_overlay.dart';

/// Escanea el QR de la misión. El sello solo se confirma cuando el servidor
/// responde; sin conexión el escaneo queda "pendiente de validación".
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  ScanOutcome? _outcome;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _outcome != null) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    final uid = ref.read(currentUidProvider);
    if (raw == null || uid == null) return;

    setState(() => _processing = true);
    await _controller.stop();
    ScanOutcome outcome;
    try {
      final result = await ref.read(redeemStampUseCaseProvider).execute(uid, raw);
      outcome = ScanOutcome.result(result);
      ref.read(pendingRedemptionsProvider.notifier).reload();
    } catch (error) {
      outcome = ScanOutcome.error(error);
    }
    if (!mounted) return;
    setState(() {
      _processing = false;
      _outcome = outcome;
    });
  }

  Future<void> _scanAgain() async {
    setState(() => _outcome = null);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    if (outcome != null) {
      return RedemptionResultView(
        outcome: outcome,
        onScanAgain: _scanAgain,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final cutOut = MediaQuery.sizeOf(context).shortestSide * 0.72;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Escanear sello')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const _CameraError(),
          ),
          IgnorePointer(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: AppColors.amber,
                  borderRadius: 12,
                  borderLength: 35,
                  borderWidth: 8,
                  cutOutSize: cutOut,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
              child: const Text(
                'Apunta la cámara al código QR que muestra el encargado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black87,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.amber),
                  SizedBox(height: 16),
                  Text('Validando tu sello…', style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_rounded, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'No pudimos usar la cámara.\nRevisa que la app tenga permiso para usarla en los ajustes del teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
