import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0B1B34);
  static const primary = Color(0xFF2F5BEA);
  static const background = Color(0xFFF4F6FA);
  static const border = Color(0xFFE2E7F0);
  static const textPrimary = Color(0xFF0F1B2D);
  static const textSecondary = Color(0xFF5B6B82);

  static const low = Color(0xFF1E9E6A);
  static const medium = Color(0xFFD99100);
  static const high = Color(0xFFE5622B);
  static const critical = Color(0xFFD62F45);
  static const neutral = Color(0xFF7B8798);

  /// One consistent colour per risk level, used everywhere in the app.
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
}
