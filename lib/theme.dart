import 'package:flutter/material.dart';

/// The app's palette.
abstract final class Palette {
  static const page = Color(0xFFF7F7F4);
  static const side = Color(0xFFE3E3DC);
  static const ink = Color(0xFF24272C);
  static const text = Color(0xFF17191C);
  static const muted = Color(0xFF5A5E66);
  static const faint = Color(0xFF8A8E95);
  static const line = Color(0xFFE3E3DC);
  static const track = Color(0xFFEFEFEA);
  static const marigold = Color(0xFFF2B544);
  static const butter = Color(0xFFFFEFC2);
  static const butterLight = Color(0xFFFFF7E1);
  static const cream = Color(0xFFFFF4E5);
  static const sand = Color(0xFFF0CF9C);
  static const amber = Color(0xFFA16207);
  static const alert = Color(0xFFC42B1C);
  static const alertLight = Color(0xFFFCEAE7);
  static const nightText = Color(0xFFCFCFCF);
  static const nightCard = Color(0xFF2A2C31);
  static const white = Colors.white;
}

/// Each person keeps the same colour everywhere.
Color personColor(String id) {
  const fixed = {
    'mary': Color(0xFF0E7490),
    'pracilla': Palette.amber,
    'nisha': Color(0xFF9D174D),
  };
  final color = fixed[id];
  if (color != null) return color;
  if (const {'boss', 'cielo', 'dei'}.contains(id)) return Palette.ink;
  const others = [
    Color(0xFF4D7C0F),
    Color(0xFF6D28D9),
    Color(0xFFB45309),
    Color(0xFF0F766E),
    Color(0xFFBE185D),
  ];
  return others[id.codeUnits.fold(0, (a, b) => a + b) % 5];
}

/// Page change: a short fade and rise.
class _FadeRiseTransitions extends PageTransitionsBuilder {
  const _FadeRiseTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.linear),
      ),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData buildTheme() {
  const label = TextStyle(
    fontFamily: 'DMSans',
    fontFamilyFallback: ['Roboto'],
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.ink,
    brightness: Brightness.light,
  ).copyWith(
    error: Palette.alert,
    onError: Palette.white,
    onPrimary: Palette.white,
    onSecondaryContainer: Palette.text,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    outline: Palette.line,
    outlineVariant: Palette.line,
    primary: Palette.ink,
    secondary: Palette.ink,
    secondaryContainer: Palette.butter,
    surface: Palette.white,
    surfaceBright: Palette.white,
    surfaceContainer: Palette.track,
    surfaceContainerHighest: Palette.track,
    surfaceContainerLowest: Palette.white,
  );
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: width),
  );
  WidgetStateProperty<T> selected<T>(T on, T off) =>
      WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? on : off);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'DMSans',
    fontFamilyFallback: const ['Roboto'],
    scaffoldBackgroundColor: Palette.page,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeRiseTransitions(),
        TargetPlatform.iOS: _FadeRiseTransitions(),
        TargetPlatform.windows: _FadeRiseTransitions(),
        TargetPlatform.macOS: _FadeRiseTransitions(),
        TargetPlatform.linux: _FadeRiseTransitions(),
        TargetPlatform.fuchsia: _FadeRiseTransitions(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.page,
      foregroundColor: Palette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Palette.text,
        fontFamily: 'DMSerifDisplay',
        fontFamilyFallback: ['Roboto'],
        fontSize: 26,
        height: 1.1,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: Palette.line,
    ),
    cardTheme: const CardThemeData(
      color: Palette.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        side: BorderSide(color: Colors.transparent),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: selected(Palette.ink, Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Palette.white,
      selectedColor: Palette.ink,
      checkmarkColor: Palette.white,
      labelStyle: TextStyle(color: Palette.text, fontFamily: 'DMSans'),
      secondaryLabelStyle: TextStyle(color: Palette.white, fontFamily: 'DMSans'),
      shape: StadiumBorder(),
      side: BorderSide(color: Palette.line),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      titleTextStyle: TextStyle(
        color: Palette.text,
        fontFamily: 'DMSerifDisplay',
        fontSize: 24,
      ),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink,
        foregroundColor: Palette.white,
        disabledBackgroundColor: Palette.line,
        minimumSize: const Size(0, 52),
        shape: const StadiumBorder(),
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(0, 52),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Palette.ink, width: 1.5),
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.ink, textStyle: label),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.white,
      border: border(Palette.line),
      enabledBorder: border(Palette.line),
      focusedBorder: border(Palette.ink, 2),
      floatingLabelStyle: const TextStyle(color: Palette.ink),
      isDense: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Palette.butter,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        return TextStyle(
          color: on ? Palette.ink : Palette.muted,
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Palette.ink : Palette.muted),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.ink,
      linearTrackColor: Palette.butter,
      linearMinHeight: 8,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Palette.white,
        foregroundColor: Palette.ink,
        selectedBackgroundColor: Palette.ink,
        selectedForegroundColor: Palette.white,
        side: const BorderSide(color: Palette.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: selected(Palette.white, Palette.muted),
      trackColor: selected(Palette.ink, Palette.track),
    ),
  );
}
