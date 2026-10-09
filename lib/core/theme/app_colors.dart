import 'package:flutter/material.dart';

/// Paleta oficial del Pasaporte CMO. Los colores de texto cumplen contraste
/// WCAG AA sobre fondo claro para facilitar la lectura a personas mayores.
abstract final class AppColors {
  // Identidad (colores del logo del Centro Misionero Oasis)
  static const navy = Color(0xFF0E2C74);
  static const navyDark = Color(0xFF071840);
  static const navyLight = Color(0xFF16378A);

  /// Naranja de "CENTRO" y "OASIS". Sobre él se usa texto oscuro [onOrange].
  static const orange = Color(0xFFF08A24);
  static const onOrange = Color(0xFF1F1300);

  /// Naranja oscuro para texto e íconos sobre fondo claro (contraste 5:1).
  static const orangeDark = Color(0xFFB35400);
  static const orangeSoft = Color(0xFFFFE6CC);

  /// Amarillo del trigo y los continentes. Sobre él se usa texto azul o café.
  static const yellow = Color(0xFFF5C542);
  static const yellowSoft = Color(0xFFFFF4D6);

  // Alias usados en la app (mismo color del logo).
  static const gold = yellow;
  static const goldDark = orangeDark;
  static const amber = yellow;
  static const onAmber = Color(0xFF2B1700);
  static const brown = Color(0xFF865300);

  // Superficies
  static const background = Color(0xFFFFF9F1);
  static const surface = Colors.white;
  static const surfaceTint = Color(0xFFDBE1FF);
  static const border = Color(0xFFE6DCCB);

  // Texto
  static const textPrimary = Color(0xFF13203F);
  static const textSecondary = Color(0xFF46536B);

  // Estados
  static const success = Color(0xFF1B7A3A);
  static const successSurface = Color(0xFFE3F4E8);
  static const warning = Color(0xFF8A5300);
  static const warningSurface = Color(0xFFFFF1DC);
  static const error = Color(0xFFB3261E);
  static const errorSurface = Color(0xFFFCE8E6);
  static const neutral = Color(0xFF5B6475);
  static const neutralSurface = Color(0xFFEDEFF3);
}
