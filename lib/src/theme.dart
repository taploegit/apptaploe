import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/responsive/taploe_breakpoints.dart';
import '../core/theme/taploe_colors.dart';
import '../core/theme/taploe_radius.dart';

export '../core/responsive/taploe_breakpoints.dart';
export '../core/theme/taploe_colors.dart';
export '../core/theme/taploe_radius.dart';
export '../core/theme/taploe_spacing.dart';
export '../core/theme/taploe_typography.dart';

ThemeData taploeTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final dmSans = GoogleFonts.dmSansTextTheme(base.textTheme);

  return base.copyWith(
    scaffoldBackgroundColor: TaploeColors.page,
    canvasColor: TaploeColors.page,
    colorScheme: const ColorScheme.light(
      primary: TaploeColors.blue,
      onPrimary: TaploeColors.white,
      secondary: TaploeColors.black,
      onSecondary: TaploeColors.white,
      surface: TaploeColors.white,
      onSurface: TaploeColors.text,
      error: TaploeColors.error,
      outline: TaploeColors.border,
      outlineVariant: TaploeColors.border,
    ),
    textTheme: dmSans.copyWith(
      displayLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
        height: .96,
      ),
      displayMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
        height: .98,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
        height: 1,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
      ),
      titleLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontWeight: FontWeight.w800,
        color: TaploeColors.text,
        letterSpacing: 0,
      ),
      bodyLarge: GoogleFonts.dmSans(
        color: TaploeColors.textSecondary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: GoogleFonts.dmSans(
        color: TaploeColors.textSecondary,
        height: 1.4,
        letterSpacing: 0,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontWeight: FontWeight.w800,
        color: TaploeColors.text,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: TaploeColors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TaploeColors.black,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: TaploeColors.text,
        letterSpacing: 0,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: TaploeColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.card),
        side: const BorderSide(color: TaploeColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: TaploeColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.modal),
        side: const BorderSide(color: TaploeColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: TaploeColors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TaploeColors.white,
      hintStyle: GoogleFonts.dmSans(color: TaploeColors.muted),
      labelStyle: GoogleFonts.dmSans(
        color: TaploeColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.input),
        borderSide: const BorderSide(color: TaploeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.input),
        borderSide: const BorderSide(color: TaploeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.input),
        borderSide: const BorderSide(color: TaploeColors.blue, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.input),
        borderSide: const BorderSide(color: TaploeColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaploeRadius.input),
        borderSide: const BorderSide(color: TaploeColors.error, width: 1.7),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: TaploeColors.border,
      space: 1,
      thickness: 1,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TaploeColors.blue.withValues(alpha: .22);
        }
        return TaploeColors.borderStrong;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return TaploeColors.blue;
        return TaploeColors.white;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TaploeColors.blue,
      linearTrackColor: TaploeColors.subtle,
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: TaploeColors.black,
      contentTextStyle: GoogleFonts.dmSans(
        color: TaploeColors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

extension TaploeThemeX on BuildContext {
  Color get bg => TaploeColors.page;
  Color get panel => TaploeColors.white;
  Color get border => TaploeColors.border;
  Color get text => TaploeColors.text;
  Color get muted => TaploeColors.muted;

  Size get viewport => MediaQuery.sizeOf(this);
  bool get isWide => viewport.width >= TaploeBreakpoints.wide;
  bool get isDesktop => viewport.width >= TaploeBreakpoints.desktop;
  bool get isTablet =>
      viewport.width >= TaploeBreakpoints.mobile &&
      viewport.width < TaploeBreakpoints.wide;
  bool get isMobile => viewport.width < TaploeBreakpoints.mobile;
}
