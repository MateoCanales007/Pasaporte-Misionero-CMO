import 'package:cloud_firestore/cloud_firestore.dart';

class UserPassport {
  final String id;
  final String cellId;
  final Timestamp dateOfBirth;
  final Timestamp dateOfIssue;
  final String fullName;
  final String nationality;
  final String passportNumber;
  final List<Map<String, dynamic>> stamps;
  final bool isAdmin;
  final bool canShowQR;

  UserPassport({
    this.id = '',
    required this.cellId,
    required this.dateOfBirth,
    required this.dateOfIssue,
    required this.fullName,
    required this.nationality,
    required this.passportNumber,
    this.stamps = const [],
    this.isAdmin = false,
    this.canShowQR = false,
  });

  factory UserPassport.fromMap(Map<String, dynamic> map, String documentId) {
    // ✨ EL FIX: Función segura para interpretar fechas vengan como vengan
    Timestamp parseSafeTimestamp(dynamic value) {
      if (value is Timestamp) return value; // Si ya es Timestamp, lo dejamos pasar
      if (value is String) {
        // Si es un String de texto, lo convertimos a DateTime y luego a Timestamp
        return Timestamp.fromDate(DateTime.parse(value));
      }
      return Timestamp.now(); // Valor por defecto si viene nulo o corrupto
    }

    return UserPassport(
      id: documentId,
      cellId: map['cellId'] ?? '',

      // ✨ Aplicamos la función segura a tus fechas
      dateOfBirth: parseSafeTimestamp(map['dateOfBirth']),
      dateOfIssue: parseSafeTimestamp(map['dateOfIssue']),

      fullName: map['fullName'] ?? 'Misionero',
      nationality: map['nationality'] ?? 'Nacionalidad Desconocida',
      passportNumber: map['passportNumber'] ?? 'PM-0000',
      stamps: List<Map<String, dynamic>>.from(map['stamps'] ?? []),
      isAdmin: map['isAdmin'] ?? false,
      canShowQR: map['canShowQR'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'dateOfBirth': dateOfBirth,
      'dateOfIssue': dateOfIssue,
      'fullName': fullName,
      'nationality': nationality,
      'passportNumber': passportNumber,
      'stamps': stamps,
      'isAdmin': isAdmin,
      'canShowQR': canShowQR,
    };
  }
}