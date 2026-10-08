/// Errores de dominio. El [message] siempre está en español y es apto para
/// mostrarse al usuario; los detalles técnicos nunca llegan a la interfaz.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No hay conexión a internet. Revisa tu conexión e inténtalo de nuevo.']);
}

class UnauthenticatedException extends AppException {
  const UnauthenticatedException([super.message = 'Tu sesión terminó. Vuelve a iniciar sesión.']);
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'No tienes permiso para realizar esta acción.']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'No encontramos la información solicitada.']);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {this.field});

  final String? field;
}

/// Un documento tiene datos obligatorios ausentes o con formato inválido.
class DataParseException extends AppException {
  const DataParseException(this.detail) : super('Hay información dañada que no se pudo leer.');

  final String detail;

  @override
  String toString() => 'DataParseException: $detail';
}

class UnknownException extends AppException {
  const UnknownException([super.message = 'Ocurrió un problema inesperado. Inténtalo de nuevo.']);
}

/// Convierte cualquier error en un mensaje amigable.
String friendlyErrorMessage(Object error) {
  if (error is AppException) return error.message;
  return const UnknownException().message;
}
