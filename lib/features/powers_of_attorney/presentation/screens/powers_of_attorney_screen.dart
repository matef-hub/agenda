import 'package:flutter/material.dart';
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
        title: const Text('فهرس التوكيلات'),
        backgroundColor: AppColors.primaryOlive,
        foregroundColor: Colors.white,
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
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    AppColors.tableHeaderOrange
                                        .withValues(alpha: 0.3)),
                                columns: const [
                                  DataColumn(label: Text('م')),
                                  DataColumn(label: Text('اسم الموكل')),
                                  DataColumn(label: Text('رقم التوكيل')),
                                  DataColumn(label: Text('مكتب التوثيق')),
                                  DataColumn(label: Text('نوعه')),
                                  DataColumn(label: Text('التاريخ')),
                                  DataColumn(label: Text('إجراء')),
                                ],
                                rows: _filteredList.map((poa) {
                                  return DataRow(
                                    onSelectChanged: (_) =>
                                        _showAddEditDialog(poa: poa),
                                    cells: [
                                      DataCell(
                                          Text(poa['id'].toString())),
                                      DataCell(Text(
                                          poa['client_name'] ?? '')),
                                      DataCell(Text(
                                          poa['poa_number'] ?? '')),
                                      DataCell(Text(
                                          poa['notarization_office'] ??
                                              '')),
                                      DataCell(
                                          Text(poa['poa_type'] ?? '')),
                                      DataCell(
                                          Text(poa['poa_date'] ?? '')),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: AppColors.accentRed,
                                              size: 20),
                                          onPressed: () =>
                                              _deletePoa(poa['id']),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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
