import 'package:flutter/material.dart';

/// Shared brand palette: teal-forward, works in light login and dark in-app surfaces.
abstract final class AppColors {
  static const Color brandTeal = Color(0xFF0D9488);
  static const Color brandTealDark = Color(0xFF0F766E);
  static const Color brandMint = Color(0xFF5EEAD4);
  static const Color brandGlow = Color(0xFFB2F5EA);

  // Light login / global light surfaces
  static const Color scaffoldLight = Color(0xFFF8FAFC);
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderSubtleLight = Color(0xFFE2E8F0);
  static const Color textMutedLight = Color(0xFF64748B);
  static const Color textPrimaryLight = Color(0xFF0F172A);

  /// Very soft cool background for main app (lists, detail, nav).
  static const Color shellBackground = Color(0xFFF2F8F8);
  static const Color shellSegmentTrack = Color(0xFFDFF2F0);
  static const Color shellSurfaceTint = Color(0xFFE8F6F4);

  // Dark in-app (legacy / darkTheme only)
  static const Color pageBgDark = Color(0xFF131A19);
  static const Color surfaceDark = Color(0xFF1E2826);
  static const Color segmentInactiveDark = Color(0xFF121A18);
}
