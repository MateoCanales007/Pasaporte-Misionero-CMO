import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_passport.dart';

// Este proveedor escucha la colección completa en tiempo real
final communityStreamProvider = StreamProvider<List<UserPassport>>((ref) {
  return FirebaseFirestore.instance
      .collection('user_passport')
      .snapshots()
      .map((snapshot) {
    // Transformamos cada documento de Firestore en un objeto UserPassport seguro
    return snapshot.docs
        .map((doc) => UserPassport.fromMap(doc.data(), doc.id))
        .toList();
  });
});