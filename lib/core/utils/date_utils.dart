import 'arabic_format.dart';

import 'package:intl/intl.dart';

/// Utility class for handling Gregorian and Hijri date formatting.
///
/// ## Hijri Calendar Convention
///
/// This implementation uses the **tabular Islamic calendar** (also called the
/// arithmetic or civil Hijri calendar) for Gregorian-to-Hijri conversion.
///
/// The tabular calendar uses a fixed 30-year cycle where:
/// - 19 years have 354 days (common years).
/// - 11 years have 355 days (leap years).
/// - Total cycle length: 10631 days.
/// - Leap years in each 30-year cycle: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.
/// - Epoch: 1 Muharram 1 AH = JDN 1948440 (Friday, 16 July 622 CE Julian).
///
/// ### Known Regional Differences
///
/// - **Saudi Arabia (Umm al-Qura)**: The official calendar is based on
///   astronomical computation and may differ by ±1–2 days from the tabular
///   calendar, especially around month boundaries.
/// - **Other countries**: Actual moon sighting may cause ±1 day variation
///   compared to any computed calendar.
///
/// ### Limitations
///
/// - This algorithm is valid for dates from 1 Muharram 1 AH onward and has
///   been verified against reference tables for the range 1300–1500 AH
///   (approximately 1882–2076 CE).
/// - The tabular calendar may differ by ±1 day from observation-based
///   calendars. Do not claim exact alignment with any specific country's
///   official calendar without independent verification.
/// - This implementation works entirely offline with no external dependencies
///   beyond Dart's standard library and the `intl` package (for Gregorian
///   formatting only).
class AppDateUtils {
  AppDateUtils._();

  // ---------------------------------------------------------------------------
  // Gregorian formatting
  // ---------------------------------------------------------------------------

  /// Formats a DateTime to Gregorian day (e.g., "15").
  static String getGregorianDay(DateTime date) {
    return ArabicFormat.digits(date.day);
  }

  /// Formats a DateTime to Gregorian month name in Arabic (e.g., "يناير").
  static String getGregorianMonth(DateTime date) {
    return DateFormat('MMMM', 'ar').format(date);
  }

  /// Formats a DateTime to Gregorian year (e.g., "2026").
  static String getGregorianYear(DateTime date) {
    return ArabicFormat.digits(date.year);
  }

  /// Formats a DateTime to Arabic weekday name (e.g., "الخميس").
  static String getWeekday(DateTime date) {
    return DateFormat('EEEE', 'ar').format(date);
  }

  // ---------------------------------------------------------------------------
  // Hijri conversion and formatting
  // ---------------------------------------------------------------------------

  /// Converts a Gregorian [DateTime] to a [HijriDate] using the tabular
  /// Islamic calendar algorithm.
  ///
  /// This is a pure-Dart, offline computation with no external dependencies.
  static HijriDate gregorianToHijri(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    if (jdn < _islamicEpochJdn)
      throw ArgumentError('Date precedes Hijri epoch');
    return _jdnToHijri(jdn);
  }

  /// Returns the Hijri day number as a string (e.g., "2").
  static String getHijriDay(DateTime date) {
    return ArabicFormat.digits(gregorianToHijri(date).day);
  }

  /// Returns the Hijri month name in Arabic (e.g., "ربيع الآخر").
  static String getHijriMonth(DateTime date) {
    return gregorianToHijri(date).monthName;
  }

  /// Returns the Hijri year as a string (e.g., "1448").
  static String getHijriYear(DateTime date) {
    return ArabicFormat.digits(gregorianToHijri(date).year);
  }

  // ---------------------------------------------------------------------------
  // Hijri month names
  // ---------------------------------------------------------------------------

  /// Hijri month names in Arabic.
  static const List<String> hijriMonthNames = [
    'محرم', // 1
    'صفر', // 2
    'ربيع الأول', // 3
    'ربيع الآخر', // 4
    'جمادى الأولى', // 5
    'جمادى الآخرة', // 6
    'رجب', // 7
    'شعبان', // 8
    'رمضان', // 9
    'شوال', // 10
    'ذو القعدة', // 11
    'ذو الحجة', // 12
  ];

  // ---------------------------------------------------------------------------
  // Core algorithm — Tabular Islamic Calendar
  // ---------------------------------------------------------------------------

  /// The Julian Day Number of the Islamic epoch (1 Muharram 1 AH).
  ///
  /// This corresponds to Friday, 16 July 622 CE (Julian calendar).
  static const int _islamicEpochJdn = 1948440;

  /// Converts a Gregorian date to Julian Day Number.
  ///
  /// Uses the standard algorithm from Meeus, "Astronomical Algorithms" (2nd ed.).
  static int _gregorianToJdn(int year, int month, int day) {
    // Adjust for January/February being months 13/14 of the previous year.
    if (month <= 2) {
      year -= 1;
      month += 12;
    }

    final a = year ~/ 100;
    final b = 2 - a + (a ~/ 4);

    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;
  }

  /// Converts a Julian Day Number to a Hijri date using the iterative
  /// tabular algorithm.
  ///
  /// This approach:
  /// 1. Computes days elapsed since the Islamic epoch.
  /// 2. Determines the 30-year cycle and position within it.
  /// 3. Iterates through years and months to find the exact date.
  ///
  /// This is more robust than closed-form formulas, which can have
  /// off-by-one errors at month and year boundaries.
  static HijriDate _jdnToHijri(int jdn) {
    // Days elapsed since the epoch.
    int daysElapsed = jdn - _islamicEpochJdn;

    // A 30-year cycle has exactly 10631 days.
    final cycles = daysElapsed ~/ 10631;
    var remainingDays = daysElapsed % 10631;

    // Start from the first year of this cycle.
    var year = cycles * 30 + 1;

    // Walk through years within the cycle until we find the right one.
    while (true) {
      final yearLength = isHijriLeapYear(year) ? 355 : 354;
      if (remainingDays < yearLength) break;
      remainingDays -= yearLength;
      year++;
    }

    // Walk through months to find the right one.
    var month = 1;
    while (month <= 12) {
      final monthLength = hijriMonthLength(year, month);
      if (remainingDays < monthLength) break;
      remainingDays -= monthLength;
      month++;
    }

    // Remaining days + 1 gives the day of the month (1-indexed).
    final day = remainingDays + 1;

    return HijriDate(year: year, month: month, day: day);
  }

  /// Converts a Hijri date back to a Gregorian [DateTime].
  ///
  /// Useful for verifying round-trip accuracy and for converting
  /// user-entered Hijri dates.
  static DateTime hijriToGregorian(int hYear, int hMonth, int hDay) {
    if (hYear < 1 ||
        hMonth < 1 ||
        hMonth > 12 ||
        hDay < 1 ||
        hDay > hijriMonthLength(hYear, hMonth)) {
      throw ArgumentError('Invalid Hijri date');
    }
    final jdn = _hijriToJdn(hYear, hMonth, hDay);
    return _jdnToGregorian(jdn);
  }

  /// Converts a Hijri date to Julian Day Number.
  static int _hijriToJdn(int year, int month, int day) {
    // Days in completed years.
    int totalDays = 0;
    for (int y = 1; y < year; y++) {
      totalDays += isHijriLeapYear(y) ? 355 : 354;
    }

    // Days in completed months of the current year.
    for (int m = 1; m < month; m++) {
      totalDays += hijriMonthLength(year, m);
    }

    // Add days within the current month (day - 1 because day is 1-indexed).
    totalDays += day - 1;

    return _islamicEpochJdn + totalDays;
  }

  /// Converts a Julian Day Number to a Gregorian [DateTime].
  static DateTime _jdnToGregorian(int jdn) {
    int l = jdn + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    final j = (80 * l) ~/ 2447;
    final day = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    final month = j + 2 - 12 * l;
    final year = 100 * (n - 49) + i + l;

    return DateTime(year, month, day);
  }

  /// Returns `true` if the given Hijri [year] is a leap year in the
  /// standard 30-year tabular cycle.
  ///
  /// Leap years: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 in each cycle.
  static bool isHijriLeapYear(int year) {
    const leapYears = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};
    return leapYears.contains(year % 30);
  }

  /// Returns the number of days in a given Hijri month.
  ///
  /// - Odd months (1, 3, 5, 7, 9, 11) have 30 days.
  /// - Even months (2, 4, 6, 8, 10) have 29 days.
  /// - Month 12 (Dhul Hijjah) has 29 days in common years, 30 in leap years.
  static int hijriMonthLength(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError('Hijri month must be between 1 and 12, got $month');
    }
    if (month == 12) {
      return isHijriLeapYear(year) ? 30 : 29;
    }
    return month.isOdd ? 30 : 29;
  }
}

/// Represents a date in the Hijri (Islamic) calendar.
class HijriDate {
  /// The Hijri year (e.g., 1448).
  final int year;

  /// The Hijri month (1–12).
  final int month;

  /// The Hijri day of the month (1–30).
  final int day;

  const HijriDate({required this.year, required this.month, required this.day});

  /// Returns the Arabic name of the Hijri month.
  String get monthName {
    if (month < 1 || month > 12) return '--';
    return AppDateUtils.hijriMonthNames[month - 1];
  }

  @override
  String toString() => ArabicFormat.digits('$day $monthName $year هـ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
