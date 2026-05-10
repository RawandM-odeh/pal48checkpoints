import 'package:flutter/material.dart';

/// Consistent spacing, radii, and shadows for the light shell (home, lists).
abstract final class AppLayout {
  /// Small chips, inputs inner.
  static const double radiusSm = 10;

  /// Buttons, menus, segments.
  static const double radiusMd = 14;

  /// Cards, sheets.
  static const double radiusLg = 18;

  /// Header corners, large panels.
  static const double radiusXl = 22;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;

  /// Horizontal inset for scrollable page content (lists, sections).
  static const double pagePaddingH = 16;

  /// Standard card elevation (Material layer).
  static const double cardElevation = 3;

  /// Primary card shadow — soft depth without heavy contrast.
  static List<BoxShadow> cardShadow() {
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.07),
        blurRadius: 18,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: const Color(0xFF0D9488).withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Toolbars / floating strips (search row).
  static List<BoxShadow> toolbarShadow() {
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Bottom navigation lift.
  static List<BoxShadow> navBarShadow() {
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, -6),
      ),
    ];
  }
}
