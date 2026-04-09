import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text style hierarchy from Stitch "Kinetic Blueprint" design system
class AppTextStyles {
  AppTextStyles._();

  // ── Bricolage Grotesque — Display / Headlines ────────────────
  static TextStyle get display => GoogleFonts.bricolageGrotesque(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLg => GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.onSurface,
      );

  /// Slot numbers — Bricolage 700
  static TextStyle get slotNumber => GoogleFonts.bricolageGrotesque(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  // ── Inter — Body / UI ────────────────────────────────────────
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceMuted,
      );

  /// Labels — Inter 600 ALLCAPS 10px
  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12 * 10,
        color: AppColors.onSurfaceDim,
      );

  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12 * 12,
        color: AppColors.onSurfaceDim,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );
}
