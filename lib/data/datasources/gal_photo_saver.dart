import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import '../../domain/repositories/service_photo_repository.dart';

/// Guarda las fotos en la galería del teléfono, en el álbum "Pasaporte CMO".
class GalPhotoSaver implements PhotoSaver {
  static const album = 'Pasaporte CMO';

  @override
  bool get savesToGallery =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> saveToGallery(Uint8List bytes, {required String name}) async {
    if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) return false;
    await Gal.putImageBytes(bytes, album: album, name: name);
    return true;
  }
}
