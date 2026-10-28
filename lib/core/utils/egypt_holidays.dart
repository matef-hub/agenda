import 'arabic_format.dart';

enum EgyptDayKind { officialHoliday, weekend, courtWorkday, unconfirmed }

class EgyptDayInfo {
  final EgyptDayKind kind;
  final String label;
  final String? holidayName;
  const EgyptDayInfo(this.kind, this.label, [this.holidayName]);
}

/// Government holidays as announced through 28 October 2026.
/// Dates outside this snapshot are deliberately not guessed.
class EgyptHolidays {
  static const source =
      'https://www.presidency.eg/ar/مصر/العطلات-الرسمية/';
  static const octoberDecision =
      'https://sis.gov.eg/ar/المركز-الإعلامي/الأخبار/الخميس-8-أكتوبر-إجازة-رسمية-بمناسبة-عيد-القوات-المسلحة/';

  static const _announced = <String, String>{
    '2026-01-07': 'عيد الميلاد المجيد',
    '2026-01-29': 'ثورة ٢٥ يناير وعيد الشرطة',
    '2026-03-19': 'عيد الفطر',
    '2026-03-20': 'عيد الفطر',
    '2026-03-21': 'عيد الفطر',
    '2026-03-22': 'عيد الفطر',
    '2026-03-23': 'عيد الفطر',
    '2026-04-13': 'شم النسيم',
    '2026-04-25': 'عيد تحرير سيناء',
    '2026-05-07': 'عيد العمال',
    '2026-05-26': 'وقفة عيد الأضحى',
    '2026-05-27': 'عيد الأضحى',
    '2026-05-28': 'عيد الأضحى',
    '2026-05-29': 'عيد الأضحى',
    '2026-05-30': 'عيد الأضحى',
    '2026-05-31': 'عيد الأضحى',
    '2026-06-18': 'رأس السنة الهجرية',
    '2026-07-02': 'ذكرى ثورة ٣٠ يونيو',
    '2026-07-23': 'ثورة ٢٣ يوليو',
    '2026-08-27': 'المولد النبوي الشريف',
    '2026-10-08': 'عيد القوات المسلحة',
  };

  static EgyptDayInfo forDate(DateTime date) {
    final holiday = _announced[ArabicFormat.dateKey(date)];
    if (holiday != null) {
      return EgyptDayInfo(EgyptDayKind.officialHoliday, 'إجازة رسمية معلنة', holiday);
    }
    if (date.weekday == DateTime.friday) {
      return const EgyptDayInfo(EgyptDayKind.weekend, 'عطلة أسبوعية معتادة');
    }
    if (date.weekday == DateTime.saturday) {
      return const EgyptDayInfo(EgyptDayKind.courtWorkday, 'عمل معتاد للمحاكم — تحقق من الإجازات');
    }
    return const EgyptDayInfo(EgyptDayKind.unconfirmed, 'تحقق من الإجازات الرسمية');
  }
}
