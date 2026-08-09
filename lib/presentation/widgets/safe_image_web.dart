import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html; // Nativo de Dart, ya no necesitamos universal_html

// Esta es la función real. El compilador web la leerá y ejecutará el hack del HTML.
Widget buildSafeImage(String imageUrl) {
  final String viewId = 'html-img-${imageUrl.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
        (int viewId) {
      final img = html.ImageElement()
        ..src = imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = 'none';
      return img;
    },
  );

  return HtmlElementView(viewType: viewId);
}