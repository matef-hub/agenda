import 'dart:convert';

import 'package:agenda/core/database/database_helper.dart';
import 'package:agenda/core/reports/office_report.dart';
import 'package:agenda/core/reports/session_report_columns.dart';
import 'package:agenda/features/daily_schedule/data/models/session_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('session PDF columns put the case at the right and decisions at the left', () {
    final session = Session(
      courtName: 'المحكمة', circuit: 'الدائرة', caseNumber: '85',
      caseYear: '70ق', clientName: 'الموكل', clientCapacity: 'مستأنف',
      opponentName: 'الخصم', opponentCapacity: '', previousSession: 'السابقة',
      decision: 'القرار', notes: 'ملاحظة', sessionDate: DateTime(2026, 11, 1),
    );
    final headers = SessionReportColumns.headers.reversed.toList();
    final values = SessionReportColumns.cells(session.toMap()).reversed.toList();
    expect(headers, ['بيانات الدعوى', 'تاريخ الجلسة', 'أطراف الدعوى', 'القرارات السابقة والملاحظات']);
    expect(values[0], contains('المحكمة'));
    expect(values[1], isNotEmpty);
    expect(values[2], contains('الموكل'));
    expect(values[3], contains('ملاحظة'));
  });

  test('A4 reports include the selected sections and work across pages', () async {
    final database = DatabaseHelper.forTesting(inMemoryDatabasePath);
    try {
      await database.insert('personal_info', {
        'name': 'مكتب المحامي',
        'office_address': 'القاهرة',
        'office_tel': '12345678',
        'id_card_no': '12345678901234',
        'updated_at': DateTime.now().toIso8601String(),
      });
      final info = await OfficeReport.office(database);
      expect(info['name'], 'مكتب المحامي');
      expect(info.containsKey('id_card_no'), isFalse);
      final db = await database.database;
      for (var i = 0; i < 70; i++) {
        await db.insert('sessions', Session(
          courtName: 'محكمة القاهرة', circuit: 'مدني', caseNumber: '$i',
          caseYear: '70ق', clientName: 'موكل', clientCapacity: 'مستأنف',
          opponentName: 'خصم', opponentCapacity: 'مستأنف ضده',
          previousSession: '', decision: '', notes: '',
          sessionDate: DateTime(2026, 11, 1),
        ).toMap());
      }
      await db.insert('admin_notes', {
        'title': 'عمل', 'content': 'تفاصيل', 'note_date': '2026-11-01',
        'is_completed': 0, 'created_at': DateTime.now().toIso8601String(),
      });
      final report = await OfficeReport.generate(database, OfficeReport.sections.keys);
      expect(ascii.decode(report.take(5).toList()), '%PDF-');
      expect(report.length, greaterThan(1000));
      final oneSection = await OfficeReport.generate(database, ['admin_notes']);
      expect(ascii.decode(oneSection.take(5).toList()), '%PDF-');
      await expectLater(OfficeReport.generate(database, ['personal_info']), throwsArgumentError);
    } finally {
      await database.close();
    }
  });
}
