import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/holiday_status.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';
import '../providers/session_provider.dart';
import '../widgets/previous_hearing_lookup.dart';
import 'case_history_dialog.dart';

class AddEditSessionScreen extends StatefulWidget {
  final Session? session;
  final DateTime initialDate;
  final SessionRepository? repository;

  const AddEditSessionScreen({
    super.key,
    this.session,
    required this.initialDate,
    this.repository,
  });

  @override
  State<AddEditSessionScreen> createState() => _AddEditSessionScreenState();
}

class _AddEditSessionScreenState extends State<AddEditSessionScreen> {
  final _formKey = GlobalKey<FormState>();

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
  final _clientCapacityFocus = FocusNode();
  final _opponentCapacityFocus = FocusNode();
  List<String> _capacities = [];
  final List<bool> _expanded = [true, true, true, true];
  late final _repository = widget.repository ?? SessionRepository();

  Future<void> _loadCapacities() async {
    try {
      final values = await _repository.capacities();
      if (mounted) setState(() => _capacities = values);
    } catch (error) {
      debugPrint('Could not load capacities: $error');
    }
  }

  Widget _capacityField(TextEditingController controller, FocusNode focus) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focus,
      optionsBuilder: (value) {
        final query = ArabicFormat.normalize(value.text.trim());
        if (query.isEmpty) return const Iterable<String>.empty();
        return _capacities.where(
          (item) => ArabicFormat.normalize(item).contains(query),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 200),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(title: ArabicText(option), onTap: () => onSelected(option)),
              ],
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, fieldController, fieldFocus, onSubmitted) =>
          TextFormField(
            controller: fieldController,
            focusNode: fieldFocus,
            enabled: !_isSaving,
            textDirection: TextDirection.rtl,
            inputFormatters: const [ArabicDigitsFormatter()],
            decoration: InputDecoration(
              hintText: 'الصفة',
              filled: true,
              fillColor: AppColors.paperCream,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
    );
  }

  Widget _collapsible(int index, String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        title: ArabicText(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.brand900,
          ),
        ),
        trailing: Icon(
          _expanded[index] ? Icons.expand_less : Icons.expand_more,
        ),
        onTap: () => setState(() => _expanded[index] = !_expanded[index]),
      ),
      Visibility(visible: _expanded[index], maintainState: true, child: child),
    ],
  );

  void _lookupKeyChanged() {
    if (mounted) setState(() {});
  }

  void _usePreviousDetails(Session source) {
    for (final (controller, value) in [
      (_courtController, source.courtName),
      (_circuitController, source.circuit),
      (_clientNameController, source.clientName),
      (_opponentNameController, source.opponentName),
    ]) {
      if (controller.text.trim().isEmpty) {
        controller.text = ArabicFormat.digits(value);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCapacities();
    _selectedDate = widget.session?.sessionDate ?? widget.initialDate;

    _courtController = TextEditingController(text: widget.session?.courtName);
    _circuitController = TextEditingController(text: widget.session?.circuit);
    _caseNumberController = TextEditingController(
      text: widget.session?.caseNumber,
    );
    _caseYearController = TextEditingController(
      text: widget.session != null
          ? widget.session!.caseYear.toString()
          : widget.initialDate.year.toString(),
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

    if (widget.session == null) {
      _caseNumberController.addListener(_lookupKeyChanged);
      _caseYearController.addListener(_lookupKeyChanged);
    }
  }

  @override
  void dispose() {
    _clientCapacityFocus.dispose();
    _opponentCapacityFocus.dispose();
    _caseNumberController.removeListener(_lookupKeyChanged);
    _caseYearController.removeListener(_lookupKeyChanged);
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _expanded.fillRange(0, _expanded.length, true));
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final yearText = ArabicFormat.normalize(_caseYearController.text).replaceAll(RegExp(r'\s+'), '');
      if (!RegExp(r'^\d{1,4}\s*ق?$').hasMatch(yearText)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ArabicText('سنة الدعوى يجب أن تكون رقماً صحيحاً'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
        return;
      }
      final Object caseYear = int.tryParse(yearText) ?? yearText;

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
        createdAt: widget.session?.createdAt,
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
            backgroundColor: AppColors.accentRed,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brand800,
              onPrimary: Colors.white,
              onSurface: AppColors.brand900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || date == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const ArabicText(
          'تأجيل الجلسة',
          style: TextStyle(
            color: AppColors.brand900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ArabicText(
          'سيُحفظ قرار التأجيل في الجلسة الأصلية وتُضاف جلسة بتاريخ ${ArabicFormat.date(date)} باستخدام آخر بيانات محفوظة. احفظ أي تعديلات في النموذج أولًا.',
          style: const TextStyle(fontSize: 13, color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ArabicText(
              'إلغاء',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const ArabicText(
              'تأكيد التأجيل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<SessionProvider>();
    setState(() => _isSaving = true);
    try {
      await _repository.postpone(original, date);
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
            backgroundColor: AppColors.accentRed,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brand800,
              onPrimary: Colors.white,
              onSurface: AppColors.brand900,
            ),
          ),
          child: child!,
        );
      },
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
        backgroundColor: AppColors.paperCream,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.brand900,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.secondaryGold,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArabicText(
                    widget.session == null
                        ? 'إضافة جلسة جديدة'
                        : 'تعديل الجلسة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand900,
                    ),
                  ),
                  const ArabicText(
                    'إدارة القضايا والملفات القضائية',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (widget.session != null) ...[
              IconButton(
                tooltip: 'تأجيل مع حفظ الجلسة السابقة',
                icon: const Icon(Icons.event_repeat, color: AppColors.brand800),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.brand100),
                  ),
                ),
                onPressed: _isSaving ? null : _postpone,
              ),
              IconButton(
                tooltip: 'سجل جلسات القضية',
                icon: const Icon(Icons.history, color: AppColors.brand800),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.brand100),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (_) =>
                            CaseHistoryDialog(session: widget.session!),
                      ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ), // padding bottom for buttons
            child: Column(children: [
              // --- 1. Date & Time Card ---
              _collapsible(
                0,
                'تاريخ الجلسة',
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        key: const ValueKey('hearing-date'),
                        onTap: _isSaving ? null : () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.paperCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.brand100),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event,
                                size: 18,
                                color: AppColors.brand800,
                              ),
                              const SizedBox(width: 12),
                              ArabicText(
                                ArabicFormat.date(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand900,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: AppColors.textLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      HolidayStatus(date: _selectedDate),
                      const ArabicText('تحقق من مواعيد المحكمة المختصة.',
                          style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- 2. Court & Lawsuit Details ---
              _collapsible(
                1,
                'بيانات المحكمة والدعوى',
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (widget.session == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PreviousHearingLookup(
                            number: _caseNumberController.text,
                            year: _caseYearController.text,
                            date: _selectedDate,
                            repository: _repository,
                            onUse: _usePreviousDetails,
                            enabled: !_isSaving,
                          ),
                        ),

                      _buildModernRequiredField(
                        _courtController,
                        'اسم المحكمة',
                        'مثال: محكمة الاستئناف - القاهرة الجديدة',
                        Icons.gavel,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildModernRequiredField(
                              _circuitController,
                              'الدائرة',
                              'مثال: مدني كلي 3',
                              Icons.domain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _buildModernRequiredField(
                              _caseNumberController,
                              'رقم الدعوى',
                              'مثال: 5428',
                              Icons.numbers,
                              keyboardType: TextInputType.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildModernRequiredField(
                              _caseYearController,
                              'السنة',
                              'مثال: 2026 أو 70ق',
                              null,
                              keyboardType: TextInputType.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- 3. Litigant Parties ---
              _collapsible(
                2,
                'أطراف الخصومة والوكالة',
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Client
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.brand800,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const ArabicText(
                                'الموكل (طرفنا)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildModernRequiredField(
                              _clientNameController,
                              '',
                              'اسم الموكل رباعي',
                              Icons.person,
                              showLabel: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _capacityField(
                              _clientCapacityController,
                              _clientCapacityFocus,
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.brand50),
                      ), // Serves as separator
                      // Opponent
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondaryGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const ArabicText(
                                'الخصم (الطرف المقابل)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildModernRequiredField(
                              _opponentNameController,
                              '',
                              'اسم الخصم / الشركة',
                              Icons.person_outline,
                              showLabel: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _capacityField(
                              _opponentCapacityController,
                              _opponentCapacityFocus,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- 4. Procedures & Hearing Decision ---
              _collapsible(
                3,
                'سير الإجراءات والقرارات',
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _buildModernOptionalField(
                        _prevSessionController,
                        'الجلسة السابقة (القرار / التاريخ)',
                        'تاريخ وقرار الجلسة السابقة',
                        Icons.restore,
                      ),
                      const SizedBox(height: 12),
                      _buildModernOptionalField(
                        _decisionController,
                        'القرار الصادر / المطلوب بالجلسة',
                        'القرار الصادر في الجلسة، منطوق الحكم، أو ما تقرر اتخاذه...',
                        null,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const ArabicText(
                            'ملاحظات ومهام مطلوبة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildModernOptionalField(
                        _notesController,
                        '',
                        'إضافة تكليفات المساعدين، إيداع مذكرة، تجهيز توكيلات...',
                        null,
                        maxLines: 3,
                        showLabel: false,
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),

        // --- Bottom Action Bar ---
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            border: const Border(top: BorderSide(color: AppColors.brand100)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSession,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const ArabicText(
                      'حفظ الجلسة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.brand200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const ArabicText(
                      'إلغاء',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernRequiredField(
    TextEditingController controller,
    String label,
    String hint,
    IconData? prefixIcon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool showLabel = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              ArabicText(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const ArabicText(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          enabled: !_isSaving,
          inputFormatters: const [ArabicDigitsFormatter()],
          textDirection: TextDirection.rtl,
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brand900,
          ),
          decoration: InputDecoration(
            hintText: ArabicFormat.digits(hint),
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppColors.paperCream,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.brand800,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: Colors.black38)
                : null,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'مطلوب';
            }
            if (label == 'السنة') {
              if (!RegExp(r'^\d{1,4}\s*ق?$')
                  .hasMatch(ArabicFormat.normalize(value.trim()))) {
                return 'سنة غير صالحة';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildModernOptionalField(
    TextEditingController controller,
    String label,
    String hint,
    IconData? prefixIcon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool showLabel = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          ArabicText(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          enabled: !_isSaving,
          inputFormatters: const [ArabicDigitsFormatter()],
          textDirection: TextDirection.rtl,
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brand900,
          ),
          decoration: InputDecoration(
            hintText: ArabicFormat.digits(hint),
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppColors.paperCream,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.brand800,
                width: 1.5,
              ),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: Colors.black38)
                : null,
          ),
        ),
      ],
    );
  }
}
