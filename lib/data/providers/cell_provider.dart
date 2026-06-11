import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Este proveedor expone la lista de células directamente desde Firestore en tiempo real
final cellsStreamProvider = StreamProvider<List<Map<String, String>>>((ref) {
  return FirebaseFirestore.instance.collection('cell').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc.data()['name'] as String,
      };
    }).toList();
  });
});