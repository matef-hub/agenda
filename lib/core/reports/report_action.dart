import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../widgets/arabic_text.dart';
import 'office_report.dart';

Future<void> exportOfficeReport(BuildContext context, {DatabaseHelper? database, String? section}) async {
  final choice = section ?? await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const ArabicText('اختر البيانات للطباعة'),
      children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'all'), child: const ArabicText('كل الأقسام')),
        for (final entry in OfficeReport.sections.entries)
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, entry.key), child: ArabicText(entry.value)),
        SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext), child: const ArabicText('إلغاء')),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    final sections = choice == 'all' ? OfficeReport.sections.keys : [choice];
    final pdf = await OfficeReport.generate(database ?? DatabaseHelper(), sections);
    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تقرير الطباعة',
      fileName: choice == 'all' ? 'agenda-all.pdf' : 'agenda-$choice.pdf',
      mimeType: 'application/pdf',
      bytes: pdf,
    );
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: ArabicText('تم حفظ التقرير؛ افتحه للطباعة.')));
    }
  } catch (error) {
    debugPrint('Report export failed: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: ArabicText('تعذر حفظ التقرير. أعد المحاولة.')));
    }
  }
}
