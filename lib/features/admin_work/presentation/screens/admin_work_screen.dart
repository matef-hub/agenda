import 'package:flutter/material.dart';
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
                   Text(AppDateUtils.getHijriDay(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOlive)),
                   Text('أعمال إدارية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                   Text(AppDateUtils.getGregorianDay(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOlive)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? Center(child: Text('لا توجد أعمال مسجلة', style: TextStyle(color: AppColors.textLight)))
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(note['title'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(note['content'] ?? ''),
                                trailing: Checkbox(
                                  value: (note['is_completed'] as int?) == 1,
                                  onChanged: (val) async {
                                    await _dbHelper.update('admin_notes', {'is_completed': val! ? 1 : 0}, note['id']);
                                    _loadData();
                                  },
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
        onPressed: _showAddNoteDialog,
        backgroundColor: AppColors.primaryOlive,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}