import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'taploe_colors.dart';

abstract final class TaploeTypography {
  static TextStyle display(BuildContext context) => GoogleFonts.outfit(
    fontSize: MediaQuery.sizeOf(context).width < 720 ? 40 : 56,
    fontWeight: FontWeight.w900,
    height: .98,
    letterSpacing: 0,
    color: TaploeColors.black,
  );

  static TextStyle pageTitle(BuildContext context) => GoogleFonts.outfit(
    fontSize: MediaQuery.sizeOf(context).width < 720 ? 34 : 46,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
    color: TaploeColors.black,
  );

  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.outfit(
    fontSize: MediaQuery.sizeOf(context).width < 720 ? 24 : 30,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: 0,
    color: TaploeColors.black,
  );

  static TextStyle cardTitle(BuildContext context) => GoogleFonts.outfit(
    fontSize: 21,
    fontWeight: FontWeight.w900,
    height: 1.12,
    letterSpacing: 0,
    color: TaploeColors.black,
  );

  static TextStyle body(BuildContext context) => GoogleFonts.dmSans(
    fontSize: 16,
    height: 1.45,
    color: TaploeColors.textSecondary,
  );

  static TextStyle bodySmall(BuildContext context) =>
      GoogleFonts.dmSans(fontSize: 14, height: 1.4, color: TaploeColors.muted);

  static TextStyle label(BuildContext context) => GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0,
    color: TaploeColors.black,
  );
}
