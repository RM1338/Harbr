import 'package:flutter/material.dart';

/// Harbr Design System colors — sourced from Stitch project 14282649935075036934
/// Design philosophy: "The Kinetic Blueprint" — engineered, production-grade aesthetic
class AppColors {
  AppColors._();

  // ── Background / Surface ──────────────────────────────────────
  /// The Void — main app background
  static const Color background = Color(0xFF080808);

  /// The Base Plate — primary surface for cards and containers
  static const Color surface = Color(0xFF111111);

  /// Interaction Layer — hover states, pressed elements
  static const Color surfaceElevated = Color(0xFF1A1A1A);

  /// Section dividers / subtle containers
  static const Color surfaceHighest = Color(0xFF262626);

  // ── Text ──────────────────────────────────────────────────────
  /// Primary text
  static const Color onSurface = Color(0xFFEFEFEF);

  /// Secondary / muted text
  static const Color onSurfaceMuted = Color(0xFF888888);

  /// Section labels (ALLCAPS metadata)
  static const Color onSurfaceDim = Color(0xFF555555);

  // ── Primary Accent ────────────────────────────────────────────
  /// Electric Blue — The Signal
  static const Color primary = Color(0xFF3B82F6);

  /// Ambient glow for primary
  static const Color primaryGlow = Color(0x1F3B82F6);

  // ── Slot Status Colors ────────────────────────────────────────
  /// Available slot
  static const Color slotAvailable = Color(0xFF3B82F6);

  /// Occupied slot (blocked)
  static const Color slotOccupied = Color(0xFFEF4444);

  /// Reserved slot (user-owned)
  static const Color slotReserved = Color(0xFF8B5CF6);

  // ── Borders ───────────────────────────────────────────────────
  static const Color border = Color(0xFF262626);
  static const Color borderFaint = Color(0x66262626);

  // ── Navigation ───────────────────────────────────────────────
  static const Color navBackground = Color(0xFF080808);
  static const Color navIconInactive = Color(0xFF555555);
  static const Color navIconActive = Color(0xFF3B82F6);

  // ── Status ───────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ── Critical event row tint ──────────────────────────────────
  static const Color criticalRowBg = Color(0x143B82F6);

  // ── Ghost border (barely visible) ────────────────────────────
  static const Color ghostBorder = Color(0x663B82F6);
}
