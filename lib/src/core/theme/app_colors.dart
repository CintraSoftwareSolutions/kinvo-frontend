import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF0B1631);
  static const textPrimary = Color(0xFF0C132A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF9AA4B2);
  static const purple = Color(0xFF6F47CB);
  static const purpleLight = Color(0xFFA980F4);
  static const purpleSoft = Color(0xFFF0E8FF);
  static const purpleChip = Color(0xFFECE4FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF5F5F9);
  static const surfaceTint = Color(0xFFF6F8FF);
  static const border = Color(0xFFE4EAF2);
  static const divider = Color(0xFFE8EDF4);
  static const statusGrey = Color(0xFFC1C7D0);
  static const green = Color(0xFF0C8A67);
  static const greenSoft = Color(0xFFDDF4EE);
  static const success = Color(0xFF15B887);
  static const blue = Color(0xFF3B82F6);

  static const lightBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F0FF), Color(0xFFFDF6F6)],
  );

  static const welcomeBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6E47CB), Color(0xFFA87EF6), Color(0xFF7B54D8)],
  );
}
