import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/database_helper.dart';
import '../utils/arabic_format.dart';
import 'session_report_columns.dart';

class OfficeReport {
  static const sections = <String, String>{
    'sessions': 'الجلسات اليومية',
    'powers_of_attorney': 'التوكيلات',
    'bailiff_papers': 'أوراق المحضرين',
    'admin_notes': 'الأعمال الإدارية',
  };

  static Future<Map<String, dynamic>> office(DatabaseHelper database) async {
    final db = await database.database;
    final rows = await db.query('personal_info', columns: [
      'name', 'office_address', 'office_tel', 'mobile', 'email',
    ], orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? {} : rows.first;
  }

  static pw.Widget header(Map<String, dynamic> office, pw.Font bold, pw.Font regular) {
    final parts = <String>[];
    for (final item in [
      ('office_address', 'العنوان'),
      ('office_tel', 'هاتف المكتب'),
      ('mobile', 'الموبايل'),
      ('email', 'البريد الإلكتروني'),
    ]) {
      final value = (office[item.$1] ?? '').toString().trim();
      if (value.isNotEmpty) parts.add('${item.$2}: ${ArabicFormat.digits(value)}');
    }
    final name = (office['name'] ?? '').toString().trim();
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(name.isEmpty ? 'الأجندة القضائية' : name,
            textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: bold, fontSize: 17)),
        if (parts.isNotEmpty)
          pw.Text(parts.join('   |   '), textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right, style: pw.TextStyle(font: regular, fontSize: 9)),
      ]),
    );
  }

  static Future<Uint8List> generate(DatabaseHelper database, Iterable<String> selected) async {
    final ids = selected.toSet();
    if (ids.isEmpty || !sections.keys.toSet().containsAll(ids)) {
      throw ArgumentError('Invalid report sections');
    }
    final db = await database.database;
    final snapshot = await db.transaction((txn) async {
      final officeRows = await txn.query('personal_info', columns: [
        'name', 'office_address', 'office_tel', 'mobile', 'email',
      ], orderBy: 'id DESC', limit: 1);
      final records = <String, List<Map<String, Object?>>>{};
      for (final id in sections.keys.where(ids.contains)) {
        records[id] = await txn.query(id, orderBy: 'id DESC');
      }
      return (officeRows.isEmpty ? <String, Object?>{} : officeRows.first, records);
    });
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final document = pw.Document();
    pw.Widget cell(String value, {bool heading = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(ArabicFormat.digits(value), textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right, style: pw.TextStyle(font: heading ? bold : regular, fontSize: 10)),
    );
    String value(Map<String, Object?> row, String key) => (row[key] ?? '').toString();
    String date(Map<String, Object?> row, String key) {
      final raw = value(row, key);
      final parsed = ArabicFormat.parseDate(raw);
      return parsed == null ? raw : ArabicFormat.date(parsed);
    }
    String fields(Map<String, Object?> row, List<(String, String)> keys) =>
        keys.map((entry) => value(row, entry.$1).isEmpty ? '' : '${entry.$2}: ${value(row, entry.$1)}')
            .where((item) => item.isNotEmpty).join('\n');
    List<String> headings(String section) => switch (section) {
      'sessions' => SessionReportColumns.headers,
      'powers_of_attorney' => ['الموكل', 'رقم التوكيل والمكتب', 'النوع والتاريخ', 'ملاحظات'],
      'bailiff_papers' => ['الرقم والقلم', 'الموكل', 'التواريخ', 'الحالة والملاحظات'],
      _ => ['العنوان', 'التفاصيل', 'الموعد', 'الحالة'],
    };
    List<String> cells(String section, Map<String, Object?> row) => switch (section) {
      'sessions' => SessionReportColumns.cells(row),
      'powers_of_attorney' => [
        value(row, 'client_name'),
        fields(row, [('poa_number', 'الرقم'), ('notarization_office', 'المكتب')]),
        '${value(row, 'poa_type')}\n${date(row, 'poa_date')}',
        value(row, 'notes'),
      ],
      'bailiff_papers' => [
        fields(row, [('reference_number', 'الرقم'), ('bailiffs_office', 'القلم')]),
        value(row, 'client_name'),
        'التسليم: ${date(row, 'delivery_date')}\nالجلسة: ${date(row, 'hearing_date')}',
        fields(row, [('status', 'الحالة'), ('notes', 'ملاحظات')]),
      ],
      _ => [value(row, 'title'), value(row, 'content'), date(row, 'note_date'), row['is_completed'] == 1 ? 'مكتمل' : 'غير مكتمل'],
    };
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 10000,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      textDirection: pw.TextDirection.rtl,
      header: (_) => header(snapshot.$1, bold, regular),
      footer: (context) => pw.Center(child: cell('صفحة ${context.pageNumber}')),
      build: (_) => [
        for (final entry in snapshot.$2.entries) ...[
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: cell(sections[entry.key]!, heading: true)),
          if (entry.value.isEmpty) cell('لا توجد سجلات')
          else pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500),
            children: [
              pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: headings(entry.key).map((text) => cell(text, heading: true)).toList()),
              for (final row in entry.value)
                pw.TableRow(children: cells(entry.key, row).map((text) => cell(text)).toList()),
            ],
          ),
        ],
      ],
    ));
    return document.save();
  }
}
