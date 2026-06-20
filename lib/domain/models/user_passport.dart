import 'package:cloud_firestore/cloud_firestore.dart';

class UserPassport {
  final String cellId;
  final Timestamp dateOfBirth;
  final Timestamp dateOfIssue;
  final String fullName;
  final String nationality;
  final String passportNumber;
  final List<Map<String, dynamic>> stamps; // Coincide con el array de mapas de tu compañero

  UserPassport({
    required this.cellId,
    required this.dateOfBirth,
    required this.dateOfIssue,
    required this.fullName,
    required this.nationality,
    required this.passportNumber,
    this.stamps = const [],
  });

  // Convierte el modelo de POO Dart a Mapa JSON estricto para Firestore
  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'dateOfBirth': dateOfBirth,
      'dateOfIssue': dateOfIssue,
      'fullName': fullName,
      'nationality': nationality,
      'passportNumber': passportNumber,
      'stamps': stamps,
    };
  }
}