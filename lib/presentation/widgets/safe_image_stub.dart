import 'package:flutter/material.dart';

// Esta función es un "fantasma". El compilador de Android la leerá,
// verá que no hay código web, y nos dejará compilar el APK en paz.
Widget buildSafeImage(String imageUrl) {
  return const SizedBox();
}