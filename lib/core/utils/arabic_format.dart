import 'package:flutter/services.dart';

class ArabicFormat {
  static const _arabic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';
  static String normalize(String value) => value.split('').map((c) {
    final a = _arabic.indexOf(c);
    final p = _persian.indexOf(c);
    return a >= 0
        ? '$a'
        : p >= 0
        ? '$p'
        : c;
  }).join();
  static String digits(Object? value) =>
      normalize('$value')
          .replaceAllMapped(RegExp('[0-9]'), (m) => _arabic[int.parse(m[0]!)]);
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static DateTime shiftDay(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String date(DateTime date) =>
      '\u200F${digits(date.day)} / ${digits(date.month)} / ${digits(date.year)}\u200F';
  static DateTime? parseDate(String value) {
    final text = normalize(value).replaceAll('\u200F', '').trim();
    final match = RegExp(r'^(\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{4})$')
        .firstMatch(text);
    if (match != null) {
      final d = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      final y = int.parse(match[3]!);
      final date = DateTime(y, m, d);
      return date.year == y && date.month == m && date.day == d ? date : null;
    }
    final iso = DateTime.tryParse(text);
    if (iso == null) return null;
    // Reject dates such as 2026-02-31 that DateTime silently normalizes.
    if (text.length >= 10 && dateKey(iso) != text.substring(0, 10)) return null;
    return iso;
  }
}

class ArabicDigitsFormatter extends TextInputFormatter {
  const ArabicDigitsFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: ArabicFormat.digits(newValue.text));
}
