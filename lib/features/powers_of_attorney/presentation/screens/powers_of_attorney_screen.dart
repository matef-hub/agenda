import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database_helper.dart';

/// شاشة فهرس التوكيلات
///
/// Provides CRUD operations for powers of attorney records with:
/// - Search by client name or POA number.
/// - Sorting by client name or date.
/// - Delete with confirmation dialog.
/// - Required-field validation (client name, POA number).
/// - Loading, empty, and error states.
/// - Proper disposal of controllers.
class PowersOfAttorneyScreen extends StatefulWidget {
  const PowersOfAttorneyScreen({super.key});

  @override
  State<PowersOfAttorneyScreen> createState() => _PowersOfAttorneyScreenState();
}

class _PowersOfAttorneyScreenState extends State<PowersOfAttorneyScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _poaList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredList = List.from(_poaList);
      } else {
        _filteredList = _poaList.where((poa) {
          final name = (poa['client_name'] ?? '').toString().toLowerCase();
          final number = (poa['poa_number'] ?? '').toString().toLowerCase();
          return name.contains(query) || number.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final data = await _dbHelper.queryAll('powers_of_attorney');
      if (mounted) {
        setState(() {
          _poaList = data;
          _filteredList = List.from(data);
          _isLoading = false;
        });
        _filterList(); // Re-apply search filter.
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل التوكيلات: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePoa(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا التوكيل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.accentRed))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.delete('powers_of_attorney', id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف التوكيل: $e')),
          );
        }
      }
    }
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

  void _showAddEditDialog({Map<String, dynamic>? poa}) async {
    final formKey = GlobalKey<FormState>();
    final clientCtrl = TextEditingController(text: poa?['client_name']);
    final numberCtrl = TextEditingController(text: poa?['poa_number']);
    final officeCtrl = TextEditingController(text: poa?['notarization_office']);
    final typeCtrl = TextEditingController(text: poa?['poa_type']);
    final dateCtrl = TextEditingController(text: poa?['poa_date']);
    final notesCtrl = TextEditingController(text: poa?['notes']);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(poa == null ? 'إضافة توكيل' : 'تعديل توكيل'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: clientCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الموكل'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'رقم التوكيل'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  controller: officeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'مكتب التوثيق'),
                ),
                TextFormField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'نوعه'),
                ),
                TextFormField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'التاريخ'),
                ),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final data = {
                'client_name': clientCtrl.text.trim(),
                'poa_number': numberCtrl.text.trim(),
                'notarization_office': officeCtrl.text.trim(),
                'poa_type': typeCtrl.text.trim(),
                'poa_date': dateCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'created_at': poa?['created_at'] ??
                    DateTime.now().toIso8601String(),
              };

              try {
                if (poa == null) {
                  await _dbHelper.insert('powers_of_attorney', data);
                } else {
                  await _dbHelper.update(
                      'powers_of_attorney', data, poa['id']);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _loadData();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('فشل الحفظ: $e')),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    // Dispose controllers after dialog is closed.
    clientCtrl.dispose();
    numberCtrl.dispose();
    officeCtrl.dispose();
    typeCtrl.dispose();
    dateCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فهرس التوكيلات', style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.paperCream,
        foregroundColor: AppColors.primaryOlive,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.secondaryGold),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث باسم الموكل أو رقم التوكيل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.accentRed),
                            const SizedBox(height: 8),
                            Text(_errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.accentRed)),
                            TextButton(
                                onPressed: _loadData,
                                child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : _filteredList.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'لا توجد توكيلات مسجلة'
                                  : 'لا توجد نتائج',
                              style: const TextStyle(
                                  color: AppColors.textLight),
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primaryOlive, width: 2),
                              color: Colors.white,
                            ),
                            child: Column(
                              children: [
                                // رأس الجدول
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.tableHeaderGreen,
                                    border: Border(bottom: BorderSide(color: AppColors.primaryOlive, width: 2)),
                                  ),
                                  child: Row(
                                    children: [
                                      _headerCell('الموكل', flex: 3),
                                      _headerCell('رقم / مكتب', flex: 3),
                                      _headerCell('النوع / التاريخ', flex: 2),
                                      _headerCell('حذف', flex: 1),
                                    ],
                              ),
                                ),
                                // محتوى الجدول
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _filteredList.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5, color: AppColors.tableBorder),
                                    itemBuilder: (context, index) {
                                      final poa = _filteredList[index];
                                      return InkWell(
                                        onTap: () => _showAddEditDialog(poa: poa),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  poa['client_name'] ?? '',
                                                  style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.bold),
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
                                                      Text('رقم: ${poa['poa_number'] ?? '-'}', style: const TextStyle(fontSize: 11)),
                                                      Text(poa['notarization_office'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Container(width: 0.5, height: 30, color: AppColors.tableBorder),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(poa['poa_type'] ?? '', style: const TextStyle(fontSize: 11)),
                                                      Text(poa['poa_date'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Container(width: 0.5, height: 30, color: AppColors.tableBorder),
                                              Expanded(
                                                flex: 1,
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 20),
                                                  onPressed: () => _deletePoa(poa['id']),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryOlive,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
