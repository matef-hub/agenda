import 'package:agenda/core/utils/egypt_holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identifies weekends without assuming other dates are working days', () {
    expect(EgyptHolidays.forDate(DateTime(2026, 10, 30)).kind, EgyptDayKind.weekend);
    expect(EgyptHolidays.forDate(DateTime(2026, 10, 31)).kind, EgyptDayKind.courtWorkday);
    expect(EgyptHolidays.forDate(DateTime(2027, 10, 4)).kind, EgyptDayKind.unconfirmed);
  });

  test('uses officially announced substitute days instead of automatic shifts', () {
    final october = EgyptHolidays.forDate(DateTime(2026, 10, 8));
    expect(october.kind, EgyptDayKind.officialHoliday);
    expect(october.holidayName, 'عيد القوات المسلحة');
    expect(EgyptHolidays.forDate(DateTime(2026, 10, 6)).kind, EgyptDayKind.unconfirmed);
    expect(EgyptHolidays.forDate(DateTime(2026, 7, 2)).holidayName, 'ذكرى ثورة ٣٠ يونيو');
    expect(EgyptHolidays.forDate(DateTime(2026, 6, 30)).kind, EgyptDayKind.unconfirmed);
    expect(EgyptHolidays.forDate(DateTime(2026, 4, 25)).kind, EgyptDayKind.officialHoliday);
  });
}
