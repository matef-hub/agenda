import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// نظام التصميم (Theme) الخاص بالأجندة القضائية
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paperCream,
      primaryColor: AppColors.primaryOlive,

      // إعدادات النصوص العامة
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),

      // تصميم AppBar ليحاكي رأس الصفحة في الأجندة الورقية
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paperCream,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.amiri(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryOlive),
      ),

      // تصميم البطاقات لتشبه الورق بحدود رفيعة
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.tableBorder, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // تصميم حقول الإدخال (Input)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.tableBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.tableBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: AppColors.primaryOlive,
            width: 1.5,
          ),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textLight,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textLight,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),

      // ألوان العناصر التفاعلية (Buttons, etc.)
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryOlive,
        primary: AppColors.primaryOlive,
        secondary: AppColors.secondaryGold,
        surface: AppColors.paperCream,
        error: AppColors.accentRed,
      ),

      // تنسيق التقسيمات (Dividers)
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
