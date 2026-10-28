import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_format.dart';
import 'arabic_text.dart';

class RecordField {
  final String keyName, label;
  final bool required, date;
  final int lines;
  final List<String>? choices;
  const RecordField(
    this.keyName,
    this.label, {
    this.required = false,
    this.date = false,
    this.lines = 1,
    this.choices,
  });
}

class RecordTableScreen extends StatefulWidget {
  final String table, title, singular, empty;
  final List<RecordField> fields;
  final List<String> headers;
  final List<List<String>> columns;
  final bool completion;
  final DatabaseHelper? database;
  const RecordTableScreen({
    super.key,
    required this.table,
    required this.title,
    required this.singular,
    required this.empty,
    required this.fields,
    required this.headers,
    required this.columns,
    this.completion = false,
    this.database,
  });
  @override
  State<RecordTableScreen> createState() => _RecordTableScreenState();
}

class _RecordTableScreenState extends State<RecordTableScreen> {
  late final DatabaseHelper _db = widget.database ?? DatabaseHelper();
  final _search = TextEditingController();
  final _busyRows = <int>{};
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _more = false, _ascending = false;
  String? _error;
  int _request = 0;
  int? _completed;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _request++;
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!mounted) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = await _db.database;
      final conditions = <String>[];
      final args = <Object?>[];
      final query = ArabicFormat.normalize(_search.text.trim())
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      if (query.isNotEmpty) {
        final expressions = widget.fields.map((field) {
          var expression = "COALESCE(${field.keyName}, '')";
          const arabic = '٠١٢٣٤٥٦٧٨٩';
          const persian = '۰۱۲۳۴۵۶۷۸۹';
          for (var i = 0; i < 10; i++) {
            expression =
                "replace(replace($expression, '${arabic[i]}', '$i'), '${persian[i]}', '$i')";
          }
          args.add('%$query%');
          return "$expression LIKE ? ESCAPE '\\'";
        });
        conditions.add('(${expressions.join(' OR ')})');
      }
      if (_completed != null) {
        conditions.add('is_completed = ?');
        args.add(_completed);
      }
      if (_date != null) {
        conditions.add('note_date >= ? AND note_date < ?');
        args.addAll([
          ArabicFormat.dateKey(_date!),
          ArabicFormat.dateKey(ArabicFormat.shiftDay(_date!, 1)),
        ]);
      }
      final data = await db.query(
        widget.table,
        where: conditions.isEmpty ? null : conditions.join(' AND '),
        whereArgs: args,
        orderBy: _ascending
            ? '${widget.fields.first.keyName} ASC, id ASC'
            : 'id DESC',
        limit: 51,
        offset: append ? _rows.length : 0,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _more = data.length > 50;
        _rows = [if (append) ..._rows, ...data.take(50)];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Record load failed: $e');
      if (mounted && request == _request) {
        setState(() {
          _error = 'تعذر تحميل البيانات. أعد المحاولة.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordEditorDialog(
        database: _db,
        table: widget.table,
        title: '${record == null ? 'إضافة' : 'تعديل'} ${widget.singular}',
        fields: widget.fields,
        record: record,
        completion: widget.completion,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const ArabicText('تأكيد الحذف'),
        content: ArabicText('هل تريد حذف ${widget.singular}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ArabicText('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const ArabicText(
              'حذف',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(
      record['id'] as int,
      () => _db.delete(widget.table, record['id'] as int),
    );
  }

  Future<void> _change(int id, Future<int> Function() operation) async {
    if (_busyRows.contains(id)) return;
    setState(() => _busyRows.add(id));
    try {
      if (await operation() != 1) throw StateError('Missing record');
      if (mounted) await _load();
    } catch (e) {
      debugPrint('Record update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ArabicText('تعذر حفظ التغيير. أعد المحاولة.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRows.remove(id));
    }
  }

  String _value(Map<String, dynamic> row, String key) {
    final value = (row[key] ?? '').toString();
    final field = widget.fields.firstWhere((f) => f.keyName == key);
    if (field.date && value.isNotEmpty) {
      final date = ArabicFormat.parseDate(value);
      return '${field.label}: ${date == null ? value : ArabicFormat.date(date)}';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: ArabicText(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.brand900,
      elevation: 0,
      scrolledUnderElevation: 2,
      actions: [
        IconButton(
          tooltip: _ascending ? 'الأحدث أولاً' : 'ترتيب بالاسم',
          onPressed: () {
            setState(() => _ascending = !_ascending);
            _load();
          },
          icon: Icon(_ascending ? Icons.sort_by_alpha : Icons.schedule),
        ),
      ],
    ),
    backgroundColor: AppColors.paperCream,
    body: Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.brand50)),
          ),
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.paperCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand100),
                ),
                child: TextField(
                  controller: _search,
                  inputFormatters: const [ArabicDigitsFormatter()],
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'بحث سريع...',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.brand700),
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), _load);
                  },
                ),
              ),
        if (widget.completion)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.brand100)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _completed ?? -1,
                      style: const TextStyle(fontSize: 12, color: AppColors.brand900, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: -1, child: ArabicText('كل الأعمال')),
                        DropdownMenuItem(value: 0, child: ArabicText('غير المكتمل')),
                        DropdownMenuItem(value: 1, child: ArabicText('المكتمل')),
                      ],
                      onChanged: (value) {
                        setState(() => _completed = value == -1 ? null : value);
                        _load();
                      },
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (picked != null && mounted) {
                      setState(() => _date = picked);
                      _load();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.brand100)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range, size: 16, color: AppColors.brand700),
                        const SizedBox(width: 6),
                        ArabicText(_date == null ? 'التاريخ' : ArabicFormat.date(_date!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand800)),
                      ],
                    ),
                  ),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: 'إلغاء فلتر التاريخ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    style: IconButton.styleFrom(backgroundColor: AppColors.accentRed.withValues(alpha: 0.1)),
                    onPressed: () {
                      setState(() => _date = null);
                      _load();
                    },
                    icon: const Icon(Icons.close, size: 16, color: AppColors.accentRed),
                  ),
              ],
            ),
          ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArabicText(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const ArabicText('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _rows.isEmpty
              ? Center(
                  child: ArabicText(
                    _loading
                        ? 'جارٍ التحميل…'
                        : _search.text.isEmpty
                        ? widget.empty
                        : 'لا توجد نتائج',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80, left: 16, right: 16),
                  itemCount: _rows.length + (_more ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _rows.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: TextButton(
                          onPressed: _loading ? null : () => _load(append: true),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLow,
                            foregroundColor: AppColors.brand800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const ArabicText('عرض المزيد', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                    final row = _rows[index];
                    final id = row['id'] as int;
                    final completed = row['is_completed'] == 1;

                    // Determine card accent color
                    Color accentColor = AppColors.brand200;
                    if (widget.completion) {
                      accentColor = completed ? Colors.green : AppColors.accentOrange;
                    } else if (row['status'] != null) {
                      final status = row['status'].toString();
                      if (status.contains('تم')) {
                        accentColor = Colors.green;
                      } else if (status.contains('تعذر') || status.contains('لم')) {
                        accentColor = AppColors.accentRed;
                      } else {
                        accentColor = Colors.blue;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.tableBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand900.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _edit(row),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 4, color: accentColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          for (int colIdx = 0; colIdx < widget.columns.length; colIdx++)
                                            Expanded(
                                              flex: colIdx == 0 ? 4 : (colIdx == 1 ? 4 : 3),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                decoration: colIdx == 1 ? const BoxDecoration(border: Border(right: BorderSide(color: AppColors.brand50))) : null,
                                                child: Column(
                                                  crossAxisAlignment: colIdx == 1 ? CrossAxisAlignment.center : (colIdx == 0 ? CrossAxisAlignment.start : CrossAxisAlignment.end),
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  children: [
                                                    for (int keyIdx = 0; keyIdx < widget.columns[colIdx].length; keyIdx++)
                                                      if (widget.columns[colIdx][keyIdx] == 'is_completed')
                                                        Checkbox(
                                                          value: completed,
                                                          activeColor: AppColors.brand800,
                                                          onChanged: _busyRows.contains(id) ? null : (value) => _change(id, () => _db.update(widget.table, {'is_completed': value == true ? 1 : 0}, id)),
                                                        )
                                                      else
                                                        Padding(
                                                          padding: EdgeInsets.only(bottom: keyIdx == 0 ? 4 : 0),
                                                          child: ArabicText(
                                                            _value(row, widget.columns[colIdx][keyIdx]),
                                                            textAlign: colIdx == 1 ? TextAlign.center : (colIdx == 0 ? TextAlign.start : TextAlign.end),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: keyIdx == 0 ? 13 : 11,
                                                              fontWeight: keyIdx == 0 ? FontWeight.bold : FontWeight.w600,
                                                              color: completed ? AppColors.textLight : (keyIdx == 0 ? AppColors.brand900 : AppColors.textLight),
                                                              decoration: completed ? TextDecoration.lineThrough : null,
                                                            ),
                                                          ),
                                                        ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8, bottom: 8),
                                        child: Divider(height: 1, color: AppColors.brand50),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            onTap: () => _edit(row),
                                            child: Row(
                                              children: const [
                                                ArabicText('تعديل التفاصيل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brand800)),
                                                SizedBox(width: 4),
                                                Icon(Icons.edit_document, size: 14, color: AppColors.brand800),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                tooltip: 'حذف',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                onPressed: _busyRows.contains(id) ? null : () => _delete(row),
                                                icon: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                                  child: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'fab_${widget.table}',
      tooltip: 'إضافة ${widget.singular}',
      backgroundColor: AppColors.brand800,
      onPressed: () => _edit(),
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.secondaryGold.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: const Icon(Icons.add, size: 20, color: AppColors.secondaryGoldLight),
      ),
      label: ArabicText('إضافة ${widget.singular}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}

class RecordEditorDialog extends StatefulWidget {
  final DatabaseHelper database;
  final String table, title;
  final List<RecordField> fields;
  final Map<String, dynamic>? record;
  final bool completion;
  const RecordEditorDialog({
    super.key,
    required this.database,
    required this.table,
    required this.title,
    required this.fields,
    this.record,
    this.completion = false,
  });
  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        f.keyName: TextEditingController(
          text: ArabicFormat.digits(
            widget.record?[f.keyName] ??
                (f.keyName == 'note_date'
                    ? ArabicFormat.date(DateTime.now())
                    : ''),
          ),
        ),
    };
    for (final f in widget.fields.where((f) => f.date)) {
      final date = ArabicFormat.parseDate(_controllers[f.keyName]!.text);
      if (date != null) _controllers[f.keyName]!.text = ArabicFormat.date(date);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'created_at':
          widget.record?['created_at'] ?? DateTime.now().toIso8601String(),
      if (widget.completion)
        'is_completed': widget.record?['is_completed'] ?? 0,
    };
    for (final field in widget.fields) {
      final text = _controllers[field.keyName]!.text.trim();
      data[field.keyName] = field.date && text.isNotEmpty
          ? ArabicFormat.dateKey(ArabicFormat.parseDate(text)!)
          : ArabicFormat.normalize(text);
    }
    try {
      if (widget.record == null) {
        await widget.database.insert(widget.table, data);
      } else if (await widget.database.update(
            widget.table,
            data,
            widget.record!['id'] as int,
          ) !=
          1) {
        throw StateError('Missing record');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Record save failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر الحفظ. بياناتك ما زالت موجودة؛ أعد المحاولة.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.brand50)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand100),
                    ),
                    child: const Icon(Icons.edit_document, color: AppColors.brand800, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArabicText(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brand900)),
                        const ArabicText('إدخال البيانات', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: AppColors.brand50),
                    icon: const Icon(Icons.close, size: 18, color: AppColors.brand700),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final field in widget.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ArabicText(field.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand800)),
                                  if (field.required)
                                    const ArabicText(' *', style: TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              field.choices != null
                                  ? DropdownButtonFormField<String>(
                                      initialValue: _controllers[field.keyName]!.text.isEmpty ? null : _controllers[field.keyName]!.text,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.brand700),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand200)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand800, width: 1.5)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      items: {
                                        ...field.choices!,
                                        if (_controllers[field.keyName]!.text.isNotEmpty) _controllers[field.keyName]!.text,
                                      }.map((value) => DropdownMenuItem(value: value, child: ArabicText(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                      onChanged: _saving ? null : (value) => _controllers[field.keyName]!.text = value ?? '',
                                    )
                                  : TextFormField(
                                      controller: _controllers[field.keyName],
                                      enabled: !_saving,
                                      inputFormatters: const [ArabicDigitsFormatter()],
                                      textDirection: TextDirection.rtl,
                                      maxLines: field.lines,
                                      readOnly: field.date,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brand900),
                                      decoration: InputDecoration(
                                        hintText: field.date ? 'اختر التاريخ' : 'أدخل ${field.label}...',
                                        hintStyle: const TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.normal),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand200)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand800, width: 1.5)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixIcon: field.date
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!field.required && _controllers[field.keyName]!.text.isNotEmpty)
                                                    IconButton(
                                                      tooltip: 'مسح التاريخ',
                                                      onPressed: _saving ? null : () {
                                                        setState(() {
                                                          _controllers[field.keyName]!.clear();
                                                        });
                                                      },
                                                      icon: const Icon(Icons.close, size: 16),
                                                    ),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                                    child: Icon(Icons.calendar_today, size: 18, color: AppColors.brand700),
                                                  ),
                                                ],
                                              )
                                            : null,
                                      ),
                                      onTap: !field.date
                                          ? null
                                          : () async {
                                              final parsed = ArabicFormat.parseDate(_controllers[field.keyName]!.text);
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: parsed != null && parsed.year >= 1900 && parsed.year < 2200 ? parsed : DateTime.now(),
                                                firstDate: DateTime(1900),
                                                lastDate: DateTime(2200),
                                                builder: (context, child) {
                                                  return Theme(
                                                    data: Theme.of(context).copyWith(
                                                      colorScheme: const ColorScheme.light(
                                                        primary: AppColors.brand800,
                                                        onPrimary: Colors.white,
                                                        onSurface: AppColors.textDark,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (picked != null && mounted) {
                                                setState(() {
                                                  _controllers[field.keyName]!.text = ArabicFormat.date(picked);
                                                });
                                              }
                                            },
                                      validator: (value) {
                                        if (field.required && (value == null || value.trim().isEmpty)) {
                                          return 'هذا الحقل مطلوب';
                                        }
                                        if (field.date && value != null && value.trim().isNotEmpty && ArabicFormat.parseDate(value) == null) {
                                          return 'اختر تاريخًا صحيحًا';
                                        }
                                        return null;
                                      },
                                    ),
                            ],
                          ),
                        ),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.accentRed, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: ArabicText(_error!, style: const TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer (Actions)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.brand50)),
                color: AppColors.paperCream,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.brand200)),
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brand700,
                      ),
                      child: const ArabicText('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.brand800,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const ArabicText('حفظ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
