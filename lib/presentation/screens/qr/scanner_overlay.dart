import 'package:flutter/material.dart';

/// Marco oscuro con una ventana transparente y esquinas resaltadas.
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.65),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final effectiveLength = borderLength > cutOutSize / 2 + width / 2 ? width / 4 : borderLength;
    final effectiveCutOut = cutOutSize < width ? cutOutSize : width - borderOffset;

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
      rect.left + width / 2 - effectiveCutOut / 2 + borderOffset,
      rect.top + height / 2 - effectiveCutOut / 2 + borderOffset,
      effectiveCutOut - borderOffset * 2,
      effectiveCutOut - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)), boxPaint)
      ..restore();

    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + effectiveLength)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + effectiveLength, cutOutRect.top)
        ..moveTo(cutOutRect.right - effectiveLength, cutOutRect.top)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + effectiveLength)
        ..moveTo(cutOutRect.right, cutOutRect.bottom - effectiveLength)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - effectiveLength, cutOutRect.bottom)
        ..moveTo(cutOutRect.left + effectiveLength, cutOutRect.bottom)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - effectiveLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
