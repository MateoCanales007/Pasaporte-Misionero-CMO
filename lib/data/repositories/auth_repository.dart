import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _internalDomain = '@cmo.com';

  Future<String?> registerUser(String username, String password) async {
    try {
      // ✨ SANITIZACIÓN SILENCIOSA
      // Interceptamos lo que manda la UI y le extirpamos todos los espacios en blanco.
      final cleanUsername = username.replaceAll(' ', '').toLowerCase();
      final cleanPassword = password.replaceAll(' ', '');

      if (cleanUsername.isEmpty) {
        return 'El usuario no puede estar vacío.';
      }

      // Verificamos si el usuario ya existe en Firestore
      final snapshot = await _firestore
          .collection('user_passport') // Colección principal donde se almacena la información del pasaporte y los sellos
          .where('username', isEqualTo: cleanUsername)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return 'Este nombre de usuario ya está en uso.';
      }

      final fakeEmail = '$cleanUsername$_internalDomain';

      // Firebase Authentication gestionará el acceso seguro de los usuarios
      await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: cleanPassword,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error al registrar: $e';
    }
  }

  Future<String?> loginUser(String username, String password) async {
    try {
      // ✨ SANITIZACIÓN SILENCIOSA
      final cleanUsername = username.replaceAll(' ', '').toLowerCase();
      final cleanPassword = password.replaceAll(' ', '');

      final fakeEmail = '$cleanUsername$_internalDomain';

      await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: cleanPassword,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return 'Usuario o contraseña incorrectos.';
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  Future<void> logoutUser() async => await _auth.signOut();

  // Dentro de AuthRepository, actualiza tu metodo createPassport
  Future<void> createPassport({
    required String fullName,
    required DateTime dateOfBirth,
    required String nationality,
    required String cellId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay usuario activo');

    // Extraemos el username original quitándole el @cmo.local
    final originalUsername = user.email!.split('@')[0];

    await _firestore.collection('user_passport').doc(user.uid).set({
      'id': user.uid,
      'username': originalUsername, // Guardamos el username limpio
      'passportNumber': 'PM-${DateTime.now().year}-${user.uid.substring(0, 4).toUpperCase()}',
      'fullName': fullName,
      'nationality': nationality,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'cellId': cellId,
      'dateOfIssue': DateTime.now().toIso8601String(),
      'stamps': [],
    });
  }
}