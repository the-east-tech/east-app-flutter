import 'package:flutter/material.dart';

class AppColours {
  static const Color blue = Color(0xFF1557F2);
  static const Color blueDark = Color(0xFF0B3FB8);
  static const Color blueSoft = Color(0xFF4AA3FF);

  static const Color background = Color(0xFFF8F9FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color mutedBox = Color(0xFFF3F4F6);

  static const Color textMain = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  static const Color green = Color(0xFF00A651);
  static const Color greenSoft = Color(0xFFEAFBF1);
  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeSoft = Color(0xFFFFF3E8);
  static const Color purple = Color(0xFFB43CFF);
  static const Color red = Color(0xFFB91C1C);
  static const Color redSoft = Color(0xFFFFF1F2);
  static const Color gold = Color(0xFFF5B800);
}

class AppTextSize {
  static const double s48 = 38;
  static const double s44 = 36;
  static const double s34 = 30;
  static const double s30 = 26;
  static const double s28 = 24;
  static const double s26 = 22;
  static const double s25 = 21;
  static const double s24 = 20;
  static const double s23 = 19;
  static const double s22 = 19;
  static const double s21 = 18;
  static const double s20 = 17;
  static const double s19 = 16;
  static const double s18 = 15;
  static const double s17 = 14;
  static const double s16 = 14;
  static const double s15 = 13;
  static const double s14 = 13;
  static const double s13 = 12;
  static const double s12 = 11;
  static const double s10 = 9;
}


class AppTextStyles {
  static const TextStyle formLabel = TextStyle(
    fontSize: AppTextSize.s15,
    fontWeight: FontWeight.w500,
    color: AppColours.textMuted,
  );

  static const TextStyle formValue = TextStyle(
    fontSize: AppTextSize.s15,
    fontWeight: FontWeight.w600,
    color: AppColours.textMain,
  );

  static const TextStyle formHint = TextStyle(
    fontSize: AppTextSize.s15,
    fontWeight: FontWeight.w400,
    color: AppColours.textMuted,
  );

  static const TextStyle formSuffix = TextStyle(
    fontSize: AppTextSize.s14,
    fontWeight: FontWeight.w500,
    color: AppColours.textMuted,
  );
}

class AppInputStyle {
  static InputDecoration decoration(
    String hint, {
    String? suffixText,
    String? prefixText,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  }) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      prefixText: prefixText,
      hintStyle: AppTextStyles.formHint,
      suffixStyle: AppTextStyles.formSuffix,
      prefixStyle: AppTextStyles.formSuffix,
      filled: true,
      fillColor: AppColours.mutedBox,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: contentPadding,
    );
  }
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColours.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColours.blue,
        primary: AppColours.blue,
        secondary: AppColours.blueSoft,
        surface: AppColours.card,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTextStyles.formHint,
        suffixStyle: AppTextStyles.formSuffix,
        prefixStyle: AppTextStyles.formSuffix,
        filled: true,
        fillColor: AppColours.mutedBox,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: AppTextSize.s34,
          fontWeight: FontWeight.w800,
          color: AppColours.textMain,
        ),
        headlineMedium: TextStyle(
          fontSize: AppTextSize.s28,
          fontWeight: FontWeight.w800,
          color: AppColours.textMain,
        ),
        titleLarge: TextStyle(
          fontSize: AppTextSize.s22,
          fontWeight: FontWeight.w700,
          color: AppColours.textMain,
        ),
        titleMedium: TextStyle(
          fontSize: AppTextSize.s18,
          fontWeight: FontWeight.w600,
          color: AppColours.textMain,
        ),
        bodyLarge: TextStyle(
          fontSize: AppTextSize.s16,
          color: AppColours.textMuted,
        ),
      ),
    );
  }
}
