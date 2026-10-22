import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class BailiffsScreen extends StatefulWidget {
  const BailiffsScreen({super.key});

  @override
  State<BailiffsScreen> createState() => _BailiffsScreenState();
}

class _BailiffsScreenState extends State<BailiffsScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _papers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _dbHelper.queryAll('bailiff_papers');
    setState(() {
      _papers = data;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? paper}) async {
    final refCtrl = TextEditingController(text: paper?['reference_number']);
    final officeCtrl = TextEditingController(text: paper?['bailiffs_office']);
    final clientCtrl = TextEditingController(text: paper?['client_name']);
    final delDateCtrl = TextEditingController(text: paper?['delivery_date']);
    final hearDateCtrl = TextEditingController(text: paper?['hearing_date']);
    final statusCtrl = TextEditingController(text: paper?['status']);
    final notesCtrl = TextEditingController(text: paper?['notes']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(paper == null ? 'إضافة ورقة محضرين' : 'تعديل ورقة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: refCtrl, decoration: InputDecoration(labelText: 'الرقم')),
              TextField(controller: officeCtrl, decoration: InputDecoration(labelText: 'قلم المحضرين')),
              TextField(controller: clientCtrl, decoration: InputDecoration(labelText: 'اسم الموكل')),
              TextField(controller: delDateCtrl, decoration: InputDecoration(labelText: 'تاريخ التسليم')),
              TextField(controller: hearDateCtrl, decoration: InputDecoration(labelText: 'تاريخ الجلسة')),
              TextField(controller: statusCtrl, decoration: InputDecoration(labelText: 'الحالة')),
              TextField(controller: notesCtrl, decoration: InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'reference_number': refCtrl.text,
                'bailiffs_office': officeCtrl.text,
                'client_name': clientCtrl.text,
                'delivery_date': delDateCtrl.text,
                'hearing_date': hearDateCtrl.text,
                'status': statusCtrl.text,
                'notes': notesCtrl.text,
                'created_at': DateTime.now().toIso8601String(),
              };
                            if (paper == null) {
                await _dbHelper.insert('bailiff_papers', data);
              } else {
                await _dbHelper.update('bailiff_papers', data, paper['id']);
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
        title: const Text('أوراق المحضرين'),
        backgroundColor: AppColors.primaryOlive,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _papers.isEmpty
              ? Center(child: Text('لا توجد أوراق مسجلة', style: TextStyle(color: AppColors.textLight)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.tableHeaderGreen.withValues(alpha: 0.3)),
                      columns: const [
                        DataColumn(label: Text('الرقم')),
                        DataColumn(label: Text('قلم المحضرين')),
                        DataColumn(label: Text('اسم الموكل')),
                        DataColumn(label: Text('تاريخ التسليم')),
                        DataColumn(label: Text('تاريخ الجلسة')),
                      ],
                      rows: _papers.map((p) {
                        return DataRow(
                          onSelectChanged: (_) => _showAddEditDialog(paper: p),
                          cells: [
                            DataCell(Text(p['reference_number'] ?? '')),
                            DataCell(Text(p['bailiffs_office'] ?? '')),
                            DataCell(Text(p['client_name'] ?? '')),
                            DataCell(Text(p['delivery_date'] ?? '')),
                            DataCell(Text(p['hearing_date'] ?? '')),
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