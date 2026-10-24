import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/arabic_format.dart';
import '../models/session_model.dart';

class ScheduleExport {
  static Future<Uint8List> pdf(
    List<Session> sessions,
    DateTime date, {
    bool searchResults = false,
  }) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
    );
    final document = pw.Document();
    pw.Widget text(String value, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        ArabicFormat.digits(value),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(font: header ? bold : font, fontSize: 11),
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'الأجندة القضائية',
                style: pw.TextStyle(font: bold, fontSize: 22),
              ),
              pw.Text(
                searchResults
                    ? 'نتائج البحث في الجلسات'
                    : 'جلسات ${ArabicFormat.date(date)}',
              ),
            ],
          ),
        ),
        footer: (context) => pw.Center(
          child: pw.Text(ArabicFormat.digits('صفحة ${context.pageNumber}')),
        ),
        build: (_) => [
          pw.Table(
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xff3e5228),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xffa3b18a),
                ),
                children: [
                  text('القرار / السابقة', header: true),
                  text('الموكل / الخصم', header: true),
                  text('المحكمة / الدائرة', header: true),
                ],
              ),
              for (final session in sessions)
                pw.TableRow(
                  children: [
                    text(
                      '${session.decision}\nالسابقة: ${session.previousSession}\n${session.notes}',
                    ),
                    text(
                      'موكل: ${session.clientName}\nخصم: ${session.opponentName}',
                    ),
                    text(
                      '${session.courtName}\n${session.circuit}\nرقم ${session.caseNumber} لسنة ${session.caseYear}\n${ArabicFormat.date(session.sessionDate)}',
                    ),
                  ],
                ),
            ],
          ),
          if (sessions.isEmpty) text('لا توجد جلسات'),
        ],
      ),
    );
    return document.save();
  }

  static Uint8List calendar(List<Session> sessions) {
    String escape(String value) => value
        .replaceAll('\\', '\\\\')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
    String day(DateTime date) => ArabicFormat.dateKey(date).replaceAll('-', '');
    final now = DateTime.now().toUtc();
    final stamp =
        '${day(now)}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Judicial Agenda//AR',
      'CALSCALE:GREGORIAN',
    ];
    for (final s in sessions) {
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:session-${s.id ?? s.createdAt.microsecondsSinceEpoch}@judicial-agenda.local',
        'DTSTAMP:$stamp',
        'DTSTART;VALUE=DATE:${day(s.sessionDate)}',
        'DTEND;VALUE=DATE:${day(ArabicFormat.shiftDay(s.sessionDate, 1))}',
        'SUMMARY:${escape(ArabicFormat.digits('جلسة ${s.caseNumber} لسنة ${s.caseYear}'))}',
        'LOCATION:${escape(ArabicFormat.digits(s.courtName))}',
        'DESCRIPTION:${escape(ArabicFormat.digits('الموكل: ${s.clientName}\nالدائرة: ${s.circuit}\n${s.notes}'))}',
        'BEGIN:VALARM',
        'TRIGGER:-P1D',
        'ACTION:DISPLAY',
        'DESCRIPTION:تذكير بالجلسة',
        'END:VALARM',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    // RFC 5545 folds at 75 octets without splitting a UTF-8 character.
    final folded = lines
        .map((line) {
          final result = StringBuffer();
          var width = 0;
          for (final rune in line.runes) {
            final character = String.fromCharCode(rune);
            final length = utf8.encode(character).length;
            if (width + length > 75) {
              result.write('\r\n ');
              width = 1;
            }
            result.write(character);
            width += length;
          }
          return result.toString();
        })
        .join('\r\n');
    return Uint8List.fromList(utf8.encode('$folded\r\n'));
  }
}
