import 'package:flutter/material.dart';

/// الألوان الأساسية المستوحاة من الأجندة القضائية المصرية الورقية
class AppColors {
  AppColors._();

  // الأخضر الزيتوني الغامق - للهيدر والحدود الرئيسية
  static const Color primaryOlive = Color(0xFF3E5228);
  
  // الذهبي/البيج - للتفاصيل الثانوية والشريط الجانبي
  static const Color secondaryGold = Color(0xFFC5A059);
  
  // الكريمي الفاتح - لون خلفية الورق
  static const Color paperCream = Color(0xFFFDFBF7);
  
  // الأحمر الطوبي - لعناوين الأقسام والشعار
  static const Color accentRed = Color(0xFFB23A3A);
  
  // الأسود الفحمي - للنصوص الرئيسية
  static const Color textDark = Color(0xFF2C2C2C);
  
  // الرمادي - للنصوص الثانوية
  static const Color textLight = Color(0xFF666666);
  
  // لون حدود الجداول
  static const Color tableBorder = Color(0xFFD0D0D0);
  
  // خلفية رأس الجدول (برتقالي ترابي فاتح للتوكيلات، أخضر فاتح للمحضرين)
  static const Color tableHeaderOrange = Color(0xFFD4A373);
  static const Color tableHeaderGreen = Color(0xFFA3B18A);
  
  // ألوان إضافية للواجهة
  static const Color white = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
}