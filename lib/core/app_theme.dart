import 'package:flutter/material.dart';
import 'app_interactions.dart';

class AppTheme {
  static const _brandBlue = Color(0xFF0B4F94);
  static const _accentBlue = Color(0xFF0F84D7);
  static const _pageBackground = Color(0xFFF8FAFC);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android:
            AppPageTransitionsBuilder(PredictiveBackPageTransitionsBuilder()),
        TargetPlatform.iOS:
            AppPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
        TargetPlatform.macOS:
            AppPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      }),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF667085)),
        errorMaxLines: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      fontFamily: 'Inter',
      scaffoldBackgroundColor: _pageBackground,
      colorScheme: const ColorScheme.light(
        primary: _brandBlue,
        onPrimary: Colors.white,
        secondary: _accentBlue,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF1F2937),
        error: Color(0xFFD9534F),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _pageBackground,
        foregroundColor: _brandBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      canvasColor: _pageBackground,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accentBlue,
        circularTrackColor: Color(0xFFD9EBFF),
        linearTrackColor: Color(0xFFD9EBFF),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9EBFF),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _brandBlue
                : const Color(0xFF64748B),
          );
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _brandBlue,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _brandBlue,
        selectionColor: Color(0x332B8FD8),
        selectionHandleColor: _brandBlue,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? _brandBlue
              : const Color(0xFFCBD5E1);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFFD9EBFF)
              : const Color(0xFFE5E7EB);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? _brandBlue
              : Colors.white;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? _brandBlue
              : const Color(0xFF94A3B8);
        }),
      ),
    );
  }
}
