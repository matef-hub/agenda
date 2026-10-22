import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../providers/session_provider.dart';

class AddEditSessionScreen extends StatefulWidget {
  final Session? session; // إذا كانت null، فهي إضافة جديدة
  final DateTime initialDate;

  const AddEditSessionScreen({super.key, this.session, required this.initialDate});

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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session?.sessionDate ?? widget.initialDate;
    
    // تهيئة الـ controllers بالبيانات الموجودة (في حالة التعديل) أو فارغة
    _courtController = TextEditingController(text: widget.session?.courtName);
    _circuitController = TextEditingController(text: widget.session?.circuit);
    _caseNumberController = TextEditingController(text: widget.session?.caseNumber);
    _caseYearController = TextEditingController(text: widget.session?.caseYear.toString());
    _clientNameController = TextEditingController(text: widget.session?.clientName);
    _clientCapacityController = TextEditingController(text: widget.session?.clientCapacity);
    _opponentNameController = TextEditingController(text: widget.session?.opponentName);
    _opponentCapacityController = TextEditingController(text: widget.session?.opponentCapacity);
    _prevSessionController = TextEditingController(text: widget.session?.previousSession);
    _decisionController = TextEditingController(text: widget.session?.decision);
    _notesController = TextEditingController(text: widget.session?.notes);
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
    if (_formKey.currentState!.validate()) {
      final session = Session(
        id: widget.session?.id,
        courtName: _courtController.text,
        circuit: _circuitController.text,
        caseNumber: _caseNumberController.text,
        caseYear: int.tryParse(_caseYearController.text) ?? DateTime.now().year,
        clientName: _clientNameController.text,
        clientCapacity: _clientCapacityController.text,
        opponentName: _opponentNameController.text,
        opponentCapacity: _opponentCapacityController.text,
        previousSession: _prevSessionController.text,
        decision: _decisionController.text,
        notes: _notesController.text,
        sessionDate: _selectedDate,
        createdAt: widget.session?.createdAt,
      );

      final provider = context.read<SessionProvider>();
      if (widget.session == null) {
        await provider.addSession(session);
      } else {
        await provider.updateSession(session);
      }
      
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session == null ? 'إضافة جلسة جديدة' : 'تعديل الجلسة'),
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
              title: const Text('تاريخ الجلسة'),
              subtitle: Text(_selectedDate.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.tableBorder),
              ),
            ),
            const SizedBox(height: 16),
            
            // حقول الإدخال
            _buildTextField(_courtController, 'اسم المحكمة', 'مثال: محكمة القاهرة الجديدة'),
            const SizedBox(height: 8),
            _buildTextField(_circuitController, 'الدائرة', 'مثال: الدائرة 5 مدني'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(_caseNumberController, 'رقم الدعوى', '1234'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildTextField(_caseYearController, 'السنة', '2026', keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildTextField(_clientNameController, 'اسم الموكل', 'الاسم الكامل'),
            const SizedBox(height: 8),
            _buildTextField(_clientCapacityController, 'صفته', 'مدعي / مدعى عليه / متهم'),
            const SizedBox(height: 16),
            
            _buildTextField(_opponentNameController, 'اسم الخصم', 'الاسم الكامل'),
            const SizedBox(height: 8),
            _buildTextField(_opponentCapacityController, 'صفته', 'مدعي / مدعى عليه / سلطة اتهام'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildTextField(_prevSessionController, 'الجلسة السابقة', 'تاريخ وقرار الجلسة السابقة'),
            const SizedBox(height: 8),
            _buildTextField(_decisionController, 'القرار الحالي', 'تأجيل / حجز / حكم'),
            const SizedBox(height: 8),
            _buildTextField(_notesController, 'ملاحظات', 'أي ملاحظات إضافية', maxLines: 3),
            
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveSession,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الجلسة', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOlive,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (label.contains('المحكمة') || label.contains('الموكل') || label.contains('الخصم')) {
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';
          }
        }
        return null;
      },
    );
  }
}