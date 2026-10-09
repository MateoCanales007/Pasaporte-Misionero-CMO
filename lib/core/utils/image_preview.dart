import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Copia liviana (JPEG, lado mayor de [maxSide] px) para mostrar una foto en la
/// app sin descargar el original. Devuelve `null` si no se pudo generar.
Future<Uint8List?> buildImagePreview(Uint8List original, {int maxSide = 1000}) async {
  ui.Image? decoded;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final landscape = descriptor.width >= descriptor.height;
    final codec = await descriptor.instantiateCodec(
      targetWidth: landscape ? math.min(maxSide, descriptor.width) : null,
      targetHeight: landscape ? null : math.min(maxSide, descriptor.height),
    );
    decoded = (await codec.getNextFrame()).image;
    final rgba = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) return null;
    final image = img.Image.fromBytes(width: decoded.width, height: decoded.height, bytes: rgba.buffer, numChannels: 4);
    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  } catch (_) {
    return null;
  } finally {
    decoded?.dispose();
  }
}
