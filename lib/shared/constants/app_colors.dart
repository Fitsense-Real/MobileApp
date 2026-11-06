import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // FITSENSE - IDENTIDAD VISUAL
  // ============================================================

  /// Color principal de FitSense.
  ///
  /// Se utiliza en:
  /// - Botones principales
  /// - Enlaces
  /// - Estados activos
  /// - Indicadores
  /// - Progreso
  /// - Elementos destacados
  static const Color primary = Color(0xFFD9FF59);

  /// Variante más oscura del color principal.
  static const Color primaryDark = Color(0xFF0F2E25);

  /// Variante clara para estados secundarios.
  static const Color secondary = Color(0xFF7A9A7E);

  /// Variante muy clara para fondos/indicadores.
  static const Color primarySoft = Color(0xFFF0F6D4);

  // ============================================================
  // ESTADOS
  // ============================================================

  static const Color success = Color(0xFF22C55E);

  static const Color error = Color(0xFFFF5A5F);

  static const Color warning = Color(0xFFFFB020);

  // ============================================================
  // MODO OSCURO
  // ============================================================

  /// Fondo principal de la aplicación.
  ///
  /// Es el negro utilizado como fondo predominante
  /// en el mockup de FitSense.
  static const Color darkBackground = Color(0xFF050708);

  /// Superficie principal.
  ///
  /// Se utiliza para tarjetas, formularios y contenedores.
  static const Color darkSurface = Color(0xFF0D1112);

  /// Superficie elevada.
  ///
  /// Para elementos que necesitan diferenciarse
  /// ligeramente del resto de la interfaz.
  static const Color darkSurfaceElevated = Color(0xFF171A1B);

  /// Superficie para campos de texto.
  static const Color darkInput = Color(0xFF151919);

  /// Texto principal.
  static const Color darkText = Color(0xFFF5F7F7);

  /// Texto secundario.
  static const Color darkTextSecondary = Color(0xFFA7B0B0);

  /// Texto terciario / placeholders.
  static const Color darkTextTertiary = Color(0xFF788383);

  /// Bordes de tarjetas y campos.
  static const Color darkBorder = Color(0xFF2A3030);

  /// Borde más tenue.
  static const Color darkBorderSoft = Color(0xFF202626);

  // ============================================================
  // MODO CLARO
  // ============================================================

  /// Fondo principal en modo claro.
  static const Color lightBackground = Color(0xFFF7F5ED);

  /// Superficie blanca.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Superficie ligeramente diferenciada.
  static const Color lightSurfaceElevated = Color(0xFFF2F5F5);

  /// Fondo de campos de texto.
  static const Color lightInput = Color(0xFFF7F5ED);

  /// Texto principal.
  static const Color lightText = Color(0xFF0F2E25);

  /// Texto secundario.
  static const Color lightTextSecondary = Color(0xFF5E7865);

  /// Texto terciario / placeholders.
  static const Color lightTextTertiary = Color(0xFF8A9494);

  /// Bordes principales.
  static const Color lightBorder = Color(0xFFE1E6E6);

  /// Bordes suaves.
  static const Color lightBorderSoft = Color(0xFFEDF0F0);

  // ============================================================
  // SOMBRAS
  // ============================================================

  /// Sombra para tarjetas en modo oscuro.
  static const Color darkShadow = Color(0x55000000);

  /// Sombra para tarjetas en modo claro.
  static const Color lightShadow = Color(0x14000000);

  /// Brillo turquesa utilizado en elementos destacados.
  static const Color primaryGlow = Color(0x40D9FF59);

  // ============================================================
  // COMPATIBILIDAD CON WIDGETS EXISTENTES
  // ============================================================

  /// Estos valores se mantienen para no romper widgets
  /// que todavía utilizan nombres genéricos.

  static const Color background = lightBackground;

  static const Color surface = lightSurface;

  static const Color textPrimary = lightText;

  static const Color textSecondary = lightTextSecondary;

  static const Color border = lightBorder;
}