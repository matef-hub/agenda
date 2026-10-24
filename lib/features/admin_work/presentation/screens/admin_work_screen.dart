import 'package:flutter/material.dart';

import '../../../../core/widgets/record_table_screen.dart';

class AdminWorkScreen extends StatelessWidget {
  const AdminWorkScreen({super.key});
  @override
  Widget build(BuildContext context) => const RecordTableScreen(
    table: 'admin_notes',
    title: 'الأعمال الإدارية',
    singular: 'عمل إداري',
    empty: 'لا توجد أعمال مسجلة',
    completion: true,
    fields: [
      RecordField('title', 'العنوان', required: true),
      RecordField('content', 'التفاصيل', required: true, lines: 3),
      RecordField('note_date', 'موعد العمل', required: true, date: true),
    ],
    headers: ['العنوان / التفاصيل', 'الموعد', 'الحالة'],
    columns: [
      ['title', 'content'],
      ['note_date'],
      ['is_completed'],
    ],
  );
}
