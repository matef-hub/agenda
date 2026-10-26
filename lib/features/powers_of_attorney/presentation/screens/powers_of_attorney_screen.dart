import 'package:flutter/material.dart';

import '../../../../core/widgets/record_table_screen.dart';

class PowersOfAttorneyScreen extends StatelessWidget {
  const PowersOfAttorneyScreen({super.key});
  @override
  Widget build(BuildContext context) => const RecordTableScreen(
    table: 'powers_of_attorney',
    title: 'التوكيلات',
    singular: 'توكيل',
    empty: 'لا توجد توكيلات مسجلة',
    completion: false,
    fields: [
      RecordField('client_name', 'اسم الموكل', required: true),
      RecordField('poa_number', 'رقم التوكيل', required: true),
      RecordField('notarization_office', 'مكتب التوثيق'),
      RecordField('poa_type', 'نوع التوكيل'),
      RecordField('poa_date', 'التاريخ', date: true),
      RecordField('notes', 'ملاحظات', lines: 3),
    ],
    headers: ['الموكل', 'رقم / مكتب', 'النوع / التاريخ'],
    columns: [
      ['client_name'],
      ['poa_number', 'notarization_office'],
      ['poa_type', 'poa_date'],
    ],
  );
}
