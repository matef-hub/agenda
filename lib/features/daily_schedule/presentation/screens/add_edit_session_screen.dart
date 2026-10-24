import 'case_history_dialog.dart';
import '../../data/repositories/session_repository.dart';

import 'package:agenda/core/widgets/arabic_text.dart';

import '../../../../core/utils/arabic_format.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../providers/session_provider.dart';

class AddEditSessionScreen extends StatefulWidget {
  final Session? session; // إذا كانت null، فهي إضافة جديدة
  final DateTime initialDate;

  const AddEditSessionScreen({
    super.key,
    this.session,
    required this.initialDate,
  });

  @override
  State<AddEditSessionScreen> createState() => _AddEditSessionScreenState();
}

class _AddEditSessionScreenState extends State<AddEditSessionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers للحقول
  late TextEditingController _courtController;
  late TextEditingController _circuitController;
  late TextEditingController _caseNumberController;
  late TextEditingController _caseYearController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientCapacityController;
  late TextEditingController _opponentNameController;
  late TextEditingController _opponentCapacityController;
  late TextEditingController _prevSessionController;
  late TextEditingController _decisionController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session?.sessionDate ?? widget.initialDate;

    // تهيئة الـ controllers بالبيانات الموجودة (في حالة التعديل) أو فارغة
    _courtController = TextEditingController(text: widget.session?.courtName);
    _circuitController = TextEditingController(text: widget.session?.circuit);
    _caseNumberController = TextEditingController(
      text: widget.session?.caseNumber,
    );
    _caseYearController = TextEditingController(
      text: widget.session != null
          ? widget.session!.caseYear.toString()
          : DateTime.now().year.toString(),
    );
    _clientNameController = TextEditingController(
      text: widget.session?.clientName,
    );
    _clientCapacityController = TextEditingController(
      text: widget.session?.clientCapacity,
    );
    _opponentNameController = TextEditingController(
      text: widget.session?.opponentName,
    );
    _opponentCapacityController = TextEditingController(
      text: widget.session?.opponentCapacity,
    );
    _prevSessionController = TextEditingController(
      text: widget.session?.previousSession,
    );
    _decisionController = TextEditingController(text: widget.session?.decision);
    _notesController = TextEditingController(text: widget.session?.notes);
    for (final controller in [
      _courtController,
      _circuitController,
      _caseNumberController,
      _caseYearController,
      _clientNameController,
      _clientCapacityController,
      _opponentNameController,
      _opponentCapacityController,
      _prevSessionController,
      _decisionController,
      _notesController,
    ]) {
      controller.text = ArabicFormat.digits(controller.text);
    }
  }

  @override
  void dispose() {
    _courtController.dispose();
    _circuitController.dispose();
    _caseNumberController.dispose();
    _caseYearController.dispose();
    _clientNameController.dispose();
    _clientCapacityController.dispose();
    _opponentNameController.dispose();
    _opponentCapacityController.dispose();
    _prevSessionController.dispose();
    _decisionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final caseYear = int.tryParse(
        ArabicFormat.normalize(_caseYearController.text.trim()),
      );
      if (caseYear == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ArabicText('سنة الدعوى يجب أن تكون رقماً صحيحاً'),
            ),
          );
        }
        return;
      }

      final session = Session(
        id: widget.session?.id,
        courtName: ArabicFormat.normalize(_courtController.text.trim()),
        circuit: ArabicFormat.normalize(_circuitController.text.trim()),
        caseNumber: ArabicFormat.normalize(_caseNumberController.text.trim()),
        caseYear: caseYear,
        clientName: ArabicFormat.normalize(_clientNameController.text.trim()),
        clientCapacity: ArabicFormat.normalize(
          _clientCapacityController.text.trim(),
        ),
        opponentName: ArabicFormat.normalize(
          _opponentNameController.text.trim(),
        ),
        opponentCapacity: ArabicFormat.normalize(
          _opponentCapacityController.text.trim(),
        ),
        previousSession: ArabicFormat.normalize(
          _prevSessionController.text.trim(),
        ),
        decision: ArabicFormat.normalize(_decisionController.text.trim()),
        notes: ArabicFormat.normalize(_notesController.text.trim()),
        sessionDate: _selectedDate,
        createdAt: widget.session?.createdAt, // Preserve original createdAt
      );

      final provider = context.read<SessionProvider>();
      final saved = widget.session == null
          ? await provider.addSession(session)
          : await provider.updateSession(session);
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ArabicText(provider.errorMessage ?? 'تعذر حفظ الجلسة'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _postpone() async {
    if (_isSaving || widget.session == null) return;
    final original = widget.session!;
    final next = ArabicFormat.shiftDay(original.sessionDate, 1);
    if (next.year >= 2200) return;
    final date = await showDatePicker(
      context: context,
      initialDate: next,
      firstDate: next,
      lastDate: DateTime(2200),
    );
    if (!mounted || date == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const ArabicText('تأجيل الجلسة'),
        content: ArabicText(
          'سيُحفظ قرار التأجيل في الجلسة الأصلية وتُضاف جلسة بتاريخ ${ArabicFormat.date(date)} باستخدام آخر بيانات محفوظة. احفظ أي تعديلات في النموذج أولًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ArabicText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const ArabicText('تأكيد التأجيل'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<SessionProvider>();
    setState(() => _isSaving = true);
    try {
      await SessionRepository().postpone(original, date);
      provider.setSelectedDate(date);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Postpone failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ArabicText(
              'تعذر التأجيل. أعد فتح الجلسة ثم حاول مرة أخرى.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (mounted && picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (widget.session != null) ...[
              IconButton(
                tooltip: 'سجل جلسات القضية',
                icon: const Icon(Icons.history),
                onPressed: _isSaving
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (_) =>
                            CaseHistoryDialog(session: widget.session!),
                      ),
              ),
              IconButton(
                tooltip: 'تأجيل مع حفظ الجلسة السابقة',
                icon: const Icon(Icons.event_repeat),
                onPressed: _isSaving ? null : _postpone,
              ),
            ],
          ],
          title: ArabicText(
            widget.session == null ? 'إضافة جلسة جديدة' : 'تعديل الجلسة',
          ),
          backgroundColor: AppColors.primaryOlive,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // اختيار التاريخ
              ListTile(
                title: const ArabicText('تاريخ الجلسة'),
                subtitle: ArabicText(ArabicFormat.date(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.tableBorder),
                ),
              ),
              const SizedBox(height: 16),

              // حقول الإدخال
              _buildRequiredField(
                _courtController,
                'اسم المحكمة',
                'مثال: محكمة القاهرة الجديدة',
              ),
              const SizedBox(height: 8),
              _buildRequiredField(
                _circuitController,
                'الدائرة',
                'مثال: الدائرة 5 مدني',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildRequiredField(
                      _caseNumberController,
                      'رقم الدعوى',
                      '1234',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: _buildCaseYearField()),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              _buildRequiredField(
                _clientNameController,
                'اسم الموكل',
                'الاسم الكامل',
              ),
              const SizedBox(height: 8),
              _buildOptionalField(
                _clientCapacityController,
                'صفته',
                'مدعي / مدعى عليه / متهم',
              ),
              const SizedBox(height: 16),

              _buildRequiredField(
                _opponentNameController,
                'اسم الخصم',
                'الاسم الكامل',
              ),
              const SizedBox(height: 8),
              _buildOptionalField(
                _opponentCapacityController,
                'صفته',
                'مدعي / مدعى عليه / سلطة اتهام',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              _buildOptionalField(
                _prevSessionController,
                'الجلسة السابقة',
                'تاريخ وقرار الجلسة السابقة',
              ),
              const SizedBox(height: 8),
              _buildOptionalField(
                _decisionController,
                'القرار الحالي',
                'تأجيل / حجز / حكم',
              ),
              const SizedBox(height: 8),
              _buildOptionalField(
                _notesController,
                'ملاحظات',
                'أي ملاحظات إضافية',
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSession,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: ArabicText(
                  'حفظ الجلسة',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOlive,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a required text form field with validation.
  Widget _buildRequiredField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      enabled: !_isSaving,
      inputFormatters: const [ArabicDigitsFormatter()],
      textDirection: TextDirection.rtl,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: ArabicFormat.digits(hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  /// Builds an optional text form field without validation.
  Widget _buildOptionalField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      enabled: !_isSaving,
      inputFormatters: const [ArabicDigitsFormatter()],
      textDirection: TextDirection.rtl,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: ArabicFormat.digits(hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  /// Builds the case year field with numeric validation.
  Widget _buildCaseYearField() {
    return TextFormField(
      enabled: !_isSaving,
      inputFormatters: const [ArabicDigitsFormatter()],
      textDirection: TextDirection.rtl,
      controller: _caseYearController,
      decoration: InputDecoration(
        labelText: 'السنة',
        hintText: ArabicFormat.digits(DateTime.now().year),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        final year = int.tryParse(ArabicFormat.normalize(value.trim()));
        if (year == null) {
          return 'أدخل رقماً صحيحاً';
        }
        if (year < 1800 || year > 2200) {
          return 'سنة غير صالحة';
        }
        return null;
      },
    );
  }
}
