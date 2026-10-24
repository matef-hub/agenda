import 'package:flutter/material.dart';

import '../../../../core/widgets/record_table_screen.dart';

class BailiffsScreen extends StatelessWidget {
  const BailiffsScreen({super.key});
  @override
  Widget build(BuildContext context) => const RecordTableScreen(
    table: 'bailiff_papers',
    title: 'أوراق المحضرين',
    singular: 'ورقة محضرين',
    empty: 'لا توجد أوراق مسجلة',
    completion: false,
    fields: [
      RecordField('reference_number', 'الرقم', required: true),
      RecordField('bailiffs_office', 'قلم المحضرين', required: true),
      RecordField('client_name', 'اسم الموكل', required: true),
      RecordField('delivery_date', 'تاريخ التسليم', date: true),
      RecordField('hearing_date', 'تاريخ الجلسة', date: true),
      RecordField(
        'status',
        'الحالة',
        choices: [
          'قيد التجهيز',
          'تم التسليم',
          'تم الإعلان',
          'تعذر الإعلان',
          'تم الاستلام',
        ],
      ),
      RecordField('notes', 'ملاحظات', lines: 3),
    ],
    headers: ['الرقم / القلم', 'الموكل', 'التواريخ / الحالة'],
    columns: [
      ['reference_number', 'bailiffs_office'],
      ['client_name'],
      ['delivery_date', 'hearing_date', 'status'],
    ],
  );
}
