import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.amiri(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryOlive,
        ),
      ),
    );
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
        title: Text('أوراق المحضرين', style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.paperCream,
        foregroundColor: AppColors.primaryOlive,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.secondaryGold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _papers.isEmpty
              ? Center(child: Text('لا توجد أوراق مسجلة', style: TextStyle(color: AppColors.textLight)))
              : Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryOlive, width: 2),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.tableHeaderGreen,
                          border: Border(bottom: BorderSide(color: AppColors.primaryOlive, width: 2)),
                        ),
                        child: Row(
                          children: [
                            _headerCell('الرقم / القلم', flex: 3),
                            _headerCell('الموكل', flex: 3),
                            _headerCell('التواريخ / الحالة', flex: 3),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _papers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5, color: AppColors.tableBorder),
                          itemBuilder: (context, index) {
                            final p = _papers[index];
                            return InkWell(
                              onTap: () => _showAddEditDialog(paper: p),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['reference_number'] ?? '', style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.bold)),
                                          Text(p['bailiffs_office'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                        ],
                                      ),
                                    ),
                                    Container(width: 0.5, height: 30, color: AppColors.tableBorder),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(p['client_name'] ?? '', style: const TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                    Container(width: 0.5, height: 30, color: AppColors.tableBorder),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('تسليم: ', style: const TextStyle(fontSize: 10)),
                                            Text('جلسة: ', style: const TextStyle(fontSize: 10, color: AppColors.accentRed)),
                                            if ((p['status'] ?? '').toString().isNotEmpty)
                                              Text(p['status'], style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_bailiffs',
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryOlive,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
