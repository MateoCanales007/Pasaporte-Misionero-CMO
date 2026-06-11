import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_passport.dart';
import 'dart:math';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> loginUser(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error inesperado de autenticación';
    }
  }

  // Paso 1: Solo registra el correo y contraseña en Firebase Auth
  Future<String?> registerUser(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error al registrar: $e';
    }
  }

  // Paso 2: Crea la bitácora NoSQL (Llamado desde la nueva pantalla)
  Future<void> createPassport({
    required String fullName,
    required DateTime dateOfBirth,
    required String nationality,
    required String cellId,
  }) async {
    String uid = _auth.currentUser!.uid;
    String randomNum = Random().nextInt(9999).toString().padLeft(4, '0');
    String passportNum = "PM-2026-$randomNum";

    UserPassport newPassport = UserPassport(
      cellId: cellId,
      dateOfBirth: Timestamp.fromDate(dateOfBirth),
      dateOfIssue: Timestamp.now(),
      fullName: fullName,
      nationality: nationality,
      passportNumber: passportNum,
      stamps: const [],
    );

    // Guarda el pasaporte usando el UID como ID de documento
    await _firestore.collection('user_passport').doc(uid).set(newPassport.toMap());
  }
}