import '../utils/arabic_format.dart';

/// PDF tables lay out children from left to right, regardless of text direction.
class SessionReportColumns {
  static const headers = [
    'القرارات السابقة والملاحظات',
    'أطراف الدعوى',
    'تاريخ الجلسة',
    'بيانات الدعوى',
  ];

  static List<String> cells(Map<String, dynamic> row) {
    String value(String key) => (row[key] ?? '').toString();
    String fields(List<(String, String)> entries) => entries
        .where((entry) => value(entry.$1).trim().isNotEmpty)
        .map((entry) => '${entry.$2}: ${value(entry.$1)}')
        .join('\n');
    final date = ArabicFormat.parseDate(value('session_date'));
    return [
      fields([('previous_session', 'السابقة'), ('decision', 'القرار'), ('notes', 'ملاحظات')]),
      fields([('client_name', 'الموكل'), ('client_capacity', 'صفته'), ('opponent_name', 'الخصم'), ('opponent_capacity', 'صفته')]),
      date == null ? value('session_date') : ArabicFormat.date(date),
      '${value('court_name')}\n${value('circuit')}\nرقم ${value('case_number')} لسنة ${value('case_year')}',
    ];
  }
}
