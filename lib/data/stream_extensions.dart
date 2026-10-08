import 'dart:async';

import 'firebase_error_mapper.dart';

extension FirebaseStreamErrors<T> on Stream<T> {
  /// Convierte los errores de Firebase del stream en excepciones de dominio.
  Stream<T> mapFirebaseErrors() => transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stackTrace, sink) => sink.addError(mapFirebaseError(error), stackTrace),
    ),
  );
}
