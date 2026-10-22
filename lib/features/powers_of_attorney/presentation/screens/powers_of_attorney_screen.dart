import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class PowersOfAttorneyScreen extends StatefulWidget {
  const PowersOfAttorneyScreen({super.key});

  @override
  State<PowersOfAttorneyScreen> createState() => _PowersOfAttorneyScreenState();
}

class _PowersOfAttorneyScreenState extends State<PowersOfAttorneyScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _poaList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _dbHelper.queryAll('powers_of_attorney');
    setState(() {
      _poaList = data;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? poa}) async {
    final clientCtrl = TextEditingController(text: poa?['client_name']);
    final numberCtrl = TextEditingController(text: poa?['poa_number']);
    final officeCtrl = TextEditingController(text: poa?['notarization_office']);
    final typeCtrl = TextEditingController(text: poa?['poa_type']);
    final dateCtrl = TextEditingController(text: poa?['poa_date']);
    final notesCtrl = TextEditingController(text: poa?['notes']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(poa == null ? 'إضافة توكيل' : 'تعديل توكيل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: clientCtrl, decoration: InputDecoration(labelText: 'اسم الموكل')),
              TextField(controller: numberCtrl, decoration: InputDecoration(labelText: 'رقم التوكيل')),
              TextField(controller: officeCtrl, decoration: InputDecoration(labelText: 'مكتب التوثيق')),
              TextField(controller: typeCtrl, decoration: InputDecoration(labelText: 'نوعه')),
              TextField(controller: dateCtrl, decoration: InputDecoration(labelText: 'التاريخ')),
              TextField(controller: notesCtrl, decoration: InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'client_name': clientCtrl.text,
                'poa_number': numberCtrl.text,
                'notarization_office': officeCtrl.text,
                'poa_type': typeCtrl.text,
                'poa_date': dateCtrl.text,
                'notes': notesCtrl.text,
                'created_at': DateTime.now().toIso8601String(),
              };
                            if (poa == null) {
                await _dbHelper.insert('powers_of_attorney', data);
              } else {
                await _dbHelper.update('powers_of_attorney', data, poa['id']);
              }
              if (context.mounted) Navigator.pop(context);
              _loadData();
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس التوكيلات'),
        backgroundColor: AppColors.primaryOlive,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _poaList.isEmpty
              ? Center(child: Text('لا توجد توكيلات مسجلة', style: TextStyle(color: AppColors.textLight)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderOrange.withValues(alpha: 0.3)),
                      columns: const [
                        DataColumn(label: Text('م')),
                        DataColumn(label: Text('اسم الموكل')),
                        DataColumn(label: Text('رقم التوكيل')),
                        DataColumn(label: Text('مكتب التوثيق')),
                        DataColumn(label: Text('نوعه')),
                        DataColumn(label: Text('التاريخ')),
                      ],
                      rows: _poaList.map((poa) {
                        return DataRow(
                          onSelectChanged: (_) => _showAddEditDialog(poa: poa),
                          cells: [
                            DataCell(Text(poa['id'].toString())),
                            DataCell(Text(poa['client_name'] ?? '')),
                            DataCell(Text(poa['poa_number'] ?? '')),
                            DataCell(Text(poa['notarization_office'] ?? '')),
                            DataCell(Text(poa['poa_type'] ?? '')),
                            DataCell(Text(poa['poa_date'] ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryOlive,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}