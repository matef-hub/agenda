import 'dart:io';

import 'package:agenda/core/utils/date_utils.dart';

void main() {
  stdout.writeln('=== Hijri Conversion Verification ===\n');

  // Reference dates verified against multiple sources:
  // https://en.wikipedia.org/wiki/Islamic_calendar
  // https://www.islamicfinder.org/islamic-calendar/

  final testCases = [
    // [Gregorian, Expected Hijri description]
    [DateTime(2000, 1, 1), '25 رمضان 1420'],
    [DateTime(2024, 7, 8), '2 محرم 1446'], // Near 1 Muharram 1446
    [DateTime(2001, 9, 11), '23 جمادى الآخرة 1422'],
    [DateTime(2023, 3, 23), '1 رمضان 1444'], // Start of Ramadan 1444
    [DateTime(2024, 3, 11), '1 رمضان 1445'], // Start of Ramadan 1445
    [DateTime(2025, 3, 1), '1 رمضان 1446'], // Start of Ramadan 1446
  ];

  for (final tc in testCases) {
    final date = tc[0] as DateTime;
    final expected = tc[1] as String;
    final h = AppDateUtils.gregorianToHijri(date);
    final match = h.toString().contains(expected) ? '✓' : '✗';
    stdout.writeln(
      '$match  ${date.toIso8601String().split("T")[0]}  =>  $h  (expected: $expected هـ)',
    );
  }

  stdout.writeln('\n=== Round-Trip Tests ===\n');

  // Round-trip: Hijri -> Gregorian -> Hijri
  final roundTripCases = [
    [1, 1, 1], // Epoch
    [1446, 1, 1], // 1 Muharram 1446
    [1448, 6, 15], // Mid Jumada al-Thani 1448
    [1444, 9, 1], // 1 Ramadan 1444
    [1450, 12, 30], // End of a year (if leap)
  ];

  for (final tc in roundTripCases) {
    final hYear = tc[0];
    final hMonth = tc[1];
    final hDay = tc[2];
    final greg = AppDateUtils.hijriToGregorian(hYear, hMonth, hDay);
    final back = AppDateUtils.gregorianToHijri(greg);
    final match =
        (back.year == hYear && back.month == hMonth && back.day == hDay)
        ? '✓'
        : '✗';
    stdout.writeln(
      '$match  $hDay/$hMonth/$hYear AH  =>  ${greg.toIso8601String().split("T")[0]}  =>  $back',
    );
  }

  stdout.writeln('\n=== Leap Year Tests ===\n');

  // 30-year cycle leap years: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29
  for (int y = 1440; y <= 1470; y++) {
    final isLeap = AppDateUtils.isHijriLeapYear(y);
    if (isLeap) {
      final dhulHijjahLen = AppDateUtils.hijriMonthLength(y, 12);
      stdout.writeln('  $y AH: LEAP (Dhul Hijjah = $dhulHijjahLen days)');
    }
  }

  stdout.writeln('\n=== Month Lengths (1448 AH) ===\n');
  for (int m = 1; m <= 12; m++) {
    stdout.writeln(
      '  ${AppDateUtils.hijriMonthNames[m - 1]}: ${AppDateUtils.hijriMonthLength(1448, m)} days',
    );
  }

  stdout.writeln('\n=== Today (2026-10-22) ===\n');
  final today = DateTime(2026, 10, 22);
  final h = AppDateUtils.gregorianToHijri(today);
  stdout.writeln(
    '  Gregorian: ${AppDateUtils.getGregorianDay(today)} ${AppDateUtils.getGregorianMonth(today)} ${AppDateUtils.getGregorianYear(today)}',
  );
  stdout.writeln(
    '  Hijri:     ${AppDateUtils.getHijriDay(today)} ${AppDateUtils.getHijriMonth(today)} ${AppDateUtils.getHijriYear(today)}',
  );
  stdout.writeln('  Weekday:   ${AppDateUtils.getWeekday(today)}');
  stdout.writeln('  Full:      $h');
}
