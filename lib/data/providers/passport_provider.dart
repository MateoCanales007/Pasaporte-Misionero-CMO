import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Expone el documento exacto del usuario logueado desde Firestore
final userPassportProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('user_passport')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

// Expone de forma paralela todo el catálogo de sellos disponibles en la iglesia
final globalStampsProvider = StreamProvider<Map<String, Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('stamp').snapshots().map((snapshot) {
    Map<String, Map<String, dynamic>> stampMap = {};
    for (var doc in snapshot.docs) {
      stampMap[doc.id] = doc.data();
    }
    return stampMap;
  });
});