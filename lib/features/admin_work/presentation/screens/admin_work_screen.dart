import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

class AdminWorkScreen extends StatefulWidget {
  const AdminWorkScreen({super.key});

  @override
  State<AdminWorkScreen> createState() => _AdminWorkScreenState();
}

class _AdminWorkScreenState extends State<AdminWorkScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // For simplicity, loading all notes. In a real app, filter by date or show calendar.
    final data = await _dbHelper.queryAll('admin_notes');
    setState(() {
      _notes = data;
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

  void _showAddNoteDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('عمل إداري جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'العنوان')),
            SizedBox(height: 8),
            TextField(controller: contentCtrl, decoration: InputDecoration(labelText: 'التفاصيل'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'title': titleCtrl.text,
                'content': contentCtrl.text,
                'is_completed': 0,
                'note_date': _selectedDate.toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
              };
                            await _dbHelper.insert('admin_notes', data);
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
      body: SafeArea(
        child: Column(
          children: [
            // Header similar to Daily Schedule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.paperCream,
                border: Border(bottom: BorderSide(color: AppColors.secondaryGold, width: 2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                                      Text(AppDateUtils.getHijriDay(_selectedDate), style: GoogleFonts.amiri(fontWeight: FontWeight.bold, color: AppColors.primaryOlive, fontSize: 16)),
                   Text('أعمال إدارية', style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                   Text(AppDateUtils.getGregorianDay(_selectedDate), style: GoogleFonts.amiri(fontWeight: FontWeight.bold, color: AppColors.primaryOlive, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? Center(child: Text('لا توجد أعمال مسجلة', style: TextStyle(color: AppColors.textLight)))
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
                                    _headerCell('العنوان / التفاصيل', flex: 5),
                                    _headerCell('الحالة', flex: 1),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _notes.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5, color: AppColors.tableBorder),
                                  itemBuilder: (context, index) {
                                    final note = _notes[index];
                                    final isCompleted = (note['is_completed'] as int?) == 1;
                                    return InkWell(
                                      onTap: () async {
                                        await _dbHelper.update('admin_notes', {'is_completed': isCompleted ? 0 : 1}, note['id']);
                                        _loadData();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    note['title'] ?? 'بدون عنوان',
                                                    style: GoogleFonts.amiri(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                      color: isCompleted ? AppColors.textLight : AppColors.textDark,
                                                    ),
                                                  ),
                                                  if ((note['content'] ?? '').toString().isNotEmpty)
                                                    Text(
                                                      note['content'],
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isCompleted ? AppColors.textLight : AppColors.textDark,
                                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 0.5, height: 30, color: AppColors.tableBorder),
                                            Expanded(
                                              flex: 1,
                                              child: Icon(
                                                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                                color: isCompleted ? AppColors.primaryOlive : AppColors.tableBorder,
                                                size: 22,
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        backgroundColor: AppColors.primaryOlive,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}