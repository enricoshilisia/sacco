import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Inuka West brand colours, taken from the logo: ribbon red, sun orange,
/// and the green and blue of the figures.
class InukaColors {
  static const red = Color(0xFFD62C2C);
  static const orange = Color(0xFFF28A1E);
  static const green = Color(0xFF2E9E4F);
  static const blue = Color(0xFF1E73BE);
  static const deepRed = Color(0xFF9E1B1B);

  /// Warm sunrise gradient for primary hero surfaces.
  static const sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE2342B), Color(0xFFF28A1E)],
  );
}

/// Glassmorphic theme: transparent scaffolds so the animated backdrop
/// (widgets/glass.dart GlassBackground) shows through, translucent cards
/// and inputs with light edges, and brand colours for actions.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: InukaColors.red, brightness: brightness);
  final scheme = base.copyWith(
    primary: dark ? const Color(0xFFFF7A6B) : InukaColors.red,
    onPrimary: Colors.white,
    secondary: dark ? const Color(0xFFFFB45E) : InukaColors.orange,
    tertiary: dark ? const Color(0xFF6FD08F) : InukaColors.green,
    primaryContainer: dark ? const Color(0xFF5C1A1A) : const Color(0xFFFFE1DC),
    onPrimaryContainer: dark ? const Color(0xFFFFDAD4) : InukaColors.deepRed,
    tertiaryContainer: dark ? const Color(0xFF4A3410) : const Color(0xFFFFE8C7),
    onTertiaryContainer: dark ? const Color(0xFFFFDDB0) : const Color(0xFF5C3A00),
  );
  final glassFill = dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.62);
  final glassEdge = Colors.white.withValues(alpha: dark ? 0.16 : 0.75);
  final radius = BorderRadius.circular(20);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: scheme.onSurface, letterSpacing: -0.2),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: glassFill,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: glassEdge, width: 1.1)),
    ),
    listTileTheme: const ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: glassEdge)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: glassEdge)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        backgroundColor: glassFill,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: glassFill,
      side: BorderSide(color: glassEdge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.3 : 0.16),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: scheme.primary,
      labelColor: scheme.primary,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xF0181419) : const Color(0xF5FFFBF8),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      dragHandleColor: scheme.outlineVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xF21C171D) : const Color(0xF7FFFBF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}
