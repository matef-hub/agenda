import 'package:intl/intl.dart';

/// Utility class for handling Gregorian and Hijri date formatting
class AppDateUtils {
  AppDateUtils._();

  /// Formats a DateTime to Gregorian day (e.g., "15")
  static String getGregorianDay(DateTime date) {
    return DateFormat('d').format(date);
  }

  /// Formats a DateTime to Gregorian month name in Arabic (e.g., "يناير")
  static String getGregorianMonth(DateTime date) {
    // Using 'ar' locale for Arabic month names
    return DateFormat('MMMM', 'ar').format(date);
  }

  /// Formats a DateTime to Gregorian year (e.g., "2026")
  static String getGregorianYear(DateTime date) {
    return DateFormat('yyyy').format(date);
  }

  /// Formats a DateTime to Arabic weekday name (e.g., "السَّبْت")
  static String getWeekday(DateTime date) {
    return DateFormat('EEEE', 'ar').format(date);
  }

  /// Formats a DateTime to Hijri day (e.g., "2")
  /// Note: Uses 'ar_SA' locale which supports Hijri calendar in Dart's intl
  static String getHijriDay(DateTime date) {
    try {
      // 'ar_SA' locale uses Hijri calendar by default in many implementations
      // Format 'd' gives the day of the month
      return DateFormat('d', 'ar_SA').format(date);
    } catch (e) {
      // Fallback if ar_SA fails or isn't fully supported in the environment
      return '--';
    }
  }

  /// Formats a DateTime to Hijri month name (e.g., "جمادى الآخرة")
  static String getHijriMonth(DateTime date) {
    try {
      return DateFormat('MMMM', 'ar_SA').format(date);
    } catch (e) {
      return '--';
    }
  }

  /// Formats a DateTime to Hijri year (e.g., "1442")
  static String getHijriYear(DateTime date) {
    try {
      return DateFormat('yyyy', 'ar_SA').format(date);
    } catch (e) {
      return '--';
    }
  }
}