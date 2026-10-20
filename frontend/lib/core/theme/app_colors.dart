import 'package:flutter/material.dart';

class AppColors {
  // Brand & Backgrounds
  static const navy = Color(0xFF0A0F1D);
  static const navySurface = Color(0xFF10172A);
  static const sidebarBg = Color(0xFF0B1120);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceSubtle = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFF1E293B);

  // Brand Accents
  static const primary = Color(0xFF4F46E5);
  static const primaryHover = Color(0xFF4338CA);
  static const primaryLight = Color(0xFFEEF2FF);
  static const accent = Color(0xFF0EA5E9);
  static const accentLight = Color(0xFFF0F9FF);

  // Typography
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  // Security & Governance Risk Palette
  static const low = Color(0xFF10B981);
  static const lowBg = Color(0xFFECFDF5);
  static const medium = Color(0xFFF59E0B);
  static const mediumBg = Color(0xFFFFFBEB);
  static const high = Color(0xFFF97316);
  static const highBg = Color(0xFFFFEDD5);
  static const critical = Color(0xFFEF4444);
  static const criticalBg = Color(0xFFFEF2F2);
  static const neutral = Color(0xFF64748B);
  static const neutralBg = Color(0xFFF1F5F9);

  /// Consistent color per risk level across the entire platform.
  static Color riskColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'LOW':
        return low;
      case 'MEDIUM':
        return medium;
      case 'HIGH':
        return high;
      case 'CRITICAL':
        return critical;
      default:
        return neutral;
    }
  }

  /// Subtle background tint for risk tags.
  static Color riskBgColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'LOW':
        return lowBg;
      case 'MEDIUM':
        return mediumBg;
      case 'HIGH':
        return highBg;
      case 'CRITICAL':
        return criticalBg;
      default:
        return neutralBg;
    }
  }
}
