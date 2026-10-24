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
  const RecordField(this.keyName, this.label, {this.required = false,
    this.date = false, this.lines = 1, this.choices});
}

class RecordTableScreen extends StatefulWidget {
  final String table, title, singular, empty;
  final List<RecordField> fields;
  final List<String> headers;
  final List<List<String>> columns;
  final bool completion;
  final DatabaseHelper? database;
  const RecordTableScreen({super.key, required this.table, required this.title,
    required this.singular, required this.empty, required this.fields,
    required this.headers, required this.columns, this.completion = false,
    this.database});
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
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); _search.dispose(); _request++; super.dispose(); }

  Future<void> _load({bool append = false}) async {
    if (!mounted) return;
    final request = ++_request;
    setState(() { _loading = true; _error = null; });
    try {
      final db = await _db.database;
      final conditions = <String>[];
      final args = <Object?>[];
      final query = ArabicFormat.normalize(_search.text.trim()).replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
      if (query.isNotEmpty) {
        final expressions = widget.fields.map((field) {
          var expression = "COALESCE(${field.keyName}, '')";
          const arabic = '٠١٢٣٤٥٦٧٨٩';
          const persian = '۰۱۲۳۴۵۶۷۸۹';
          for (var i = 0; i < 10; i++) {
            expression = "replace(replace($expression, '${arabic[i]}', '$i'), '${persian[i]}', '$i')";
          }
          args.add('%$query%');
          return "$expression LIKE ? ESCAPE '\\'";
        });
        conditions.add('(${expressions.join(' OR ')})');
      }
      if (_completed != null) { conditions.add('is_completed = ?'); args.add(_completed); }
      if (_date != null) {
        conditions.add('note_date >= ? AND note_date < ?');
        args.addAll([ArabicFormat.dateKey(_date!), ArabicFormat.dateKey(ArabicFormat.shiftDay(_date!, 1))]);
      }
      final data = await db.query(widget.table,
        where: conditions.isEmpty ? null : conditions.join(' AND '), whereArgs: args,
        orderBy: _ascending ? '${widget.fields.first.keyName} ASC, id ASC' : 'id DESC',
        limit: 51, offset: append ? _rows.length : 0);
      if (!mounted || request != _request) return;
      setState(() {
        _more = data.length > 50;
        _rows = [...if (append) _rows, ...data.take(50)];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Record load failed: $e');
      if (mounted && request == _request) setState(() {
        _error = 'تعذر تحميل البيانات. أعد المحاولة.';
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    final saved = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (_) => RecordEditorDialog(database: _db, table: widget.table,
        title: '${record == null ? 'إضافة' : 'تعديل'} ${widget.singular}',
        fields: widget.fields, record: record, completion: widget.completion));
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(title: const ArabicText('تأكيد الحذف'),
        content: ArabicText('هل تريد حذف ${widget.singular}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const ArabicText('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const ArabicText('حذف', style: TextStyle(color: AppColors.accentRed))),
        ]));
    if (confirmed != true || !mounted) return;
    await _change(record['id'] as int, () => _db.delete(widget.table, record['id'] as int));
  }

  Future<void> _change(int id, Future<int> Function() operation) async {
    if (_busyRows.contains(id)) return;
    setState(() => _busyRows.add(id));
    try {
      if (await operation() != 1) throw StateError('Missing record');
      if (mounted) await _load();
    } catch (e) {
      debugPrint('Record update failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: ArabicText('تعذر حفظ التغيير. أعد المحاولة.')));
    } finally { if (mounted) setState(() => _busyRows.remove(id)); }
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
    appBar: AppBar(title: ArabicText(widget.title), actions: [
      IconButton(tooltip: _ascending ? 'الأحدث أولاً' : 'ترتيب بالاسم',
        onPressed: () { setState(() => _ascending = !_ascending); _load(); },
        icon: const Icon(Icons.sort_by_alpha)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: TextField(controller: _search, inputFormatters: const [ArabicDigitsFormatter()],
          decoration: const InputDecoration(hintText: 'بحث بالاسم أو الرقم أو التفاصيل', prefixIcon: Icon(Icons.search)),
          onChanged: (_) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 250), _load); })),
      if (widget.completion) Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, children: [
          DropdownButton<int>(value: _completed ?? -1, items: const [
            DropdownMenuItem(value: -1, child: ArabicText('كل الأعمال')),
            DropdownMenuItem(value: 0, child: ArabicText('غير المكتمل')),
            DropdownMenuItem(value: 1, child: ArabicText('المكتمل')),
          ], onChanged: (value) { setState(() => _completed = value == -1 ? null : value); _load(); }),
          TextButton.icon(icon: const Icon(Icons.date_range),
            label: ArabicText(_date == null ? 'كل التواريخ' : ArabicFormat.date(_date!)),
            onPressed: () async {
              final picked = await showDatePicker(context: context,
                initialDate: _date ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2200));
              if (picked != null && mounted) { setState(() => _date = picked); _load(); }
            }),
          if (_date != null) IconButton(tooltip: 'إلغاء فلتر التاريخ', onPressed: () {
            setState(() => _date = null); _load();
          }, icon: const Icon(Icons.close)),
        ])),
      if (_loading) const LinearProgressIndicator(),
      Expanded(child: _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ArabicText(_error!), TextButton(onPressed: _load, child: const ArabicText('إعادة المحاولة')),
      ])) : _rows.isEmpty ? Center(child: ArabicText(_loading ? 'جارٍ التحميل…' : _search.text.isEmpty ? widget.empty : 'لا توجد نتائج'))
        : Container(margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.primaryOlive, width: 2)),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(color: AppColors.tableHeaderGreen,
                border: Border(bottom: BorderSide(color: AppColors.primaryOlive, width: 2))),
              child: Row(children: [
                for (final header in widget.headers) Expanded(child: ArabicText(header,
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(width: 44),
              ])),
            Expanded(child: ListView.separated(
              itemCount: _rows.length + (_more ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.tableBorder),
              itemBuilder: (context, index) {
                if (index == _rows.length) return TextButton(onPressed: _loading ? null : () => _load(append: true),
                  child: const ArabicText('عرض المزيد'));
                final row = _rows[index];
                final id = row['id'] as int;
                final completed = row['is_completed'] == 1;
                return InkWell(onTap: () => _edit(row),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      for (final column in widget.columns) Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final key in column)
                            if (key == 'is_completed')
                              Checkbox(value: completed, onChanged: _busyRows.contains(id) ? null : (value) =>
                                _change(id, () => _db.update(widget.table, {'is_completed': value == true ? 1 : 0}, id)))
                            else ArabicText(_value(row, key), maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: completed ? AppColors.textLight : AppColors.textDark,
                                decoration: completed ? TextDecoration.lineThrough : null)),
                        ]))),
                      SizedBox(width: 44, child: IconButton(tooltip: 'حذف',
                        onPressed: _busyRows.contains(id) ? null : () => _delete(row),
                        icon: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 20))),
                    ])));
              })),
          ]))),
    ]),
    floatingActionButton: FloatingActionButton(heroTag: 'fab_${widget.table}',
      tooltip: 'إضافة ${widget.singular}', onPressed: () => _edit(), child: const Icon(Icons.add)),
  );
}

class RecordEditorDialog extends StatefulWidget {
  final DatabaseHelper database;
  final String table, title;
  final List<RecordField> fields;
  final Map<String, dynamic>? record;
  final bool completion;
  const RecordEditorDialog({super.key, required this.database, required this.table,
    required this.title, required this.fields, this.record, this.completion = false});
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
    _controllers = {for (final f in widget.fields) f.keyName: TextEditingController(
      text: ArabicFormat.digits(widget.record?[f.keyName] ?? (f.keyName == 'note_date' ? ArabicFormat.date(DateTime.now()) : '')))};
    for (final f in widget.fields.where((f) => f.date)) {
      final date = ArabicFormat.parseDate(_controllers[f.keyName]!.text);
      if (date != null) _controllers[f.keyName]!.text = ArabicFormat.date(date);
    }
  }
  @override
  void dispose() { for (final c in _controllers.values) { c.dispose(); } super.dispose(); }
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    final data = <String, dynamic>{
      'created_at': widget.record?['created_at'] ?? DateTime.now().toIso8601String(),
      if (widget.completion) 'is_completed': widget.record?['is_completed'] ?? 0,
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
      } else if (await widget.database.update(widget.table, data, widget.record!['id'] as int) != 1) {
        throw StateError('Missing record');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Record save failed: $e');
      if (mounted) setState(() { _saving = false; _error = 'تعذر الحفظ. بياناتك ما زالت موجودة؛ أعد المحاولة.'; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving,
    child: AlertDialog(title: ArabicText(widget.title),
      content: SizedBox(width: 440, child: Form(key: _form, child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final field in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12),
            child: field.choices != null ? DropdownButtonFormField<String>(
              initialValue: _controllers[field.keyName]!.text.isEmpty ? null : _controllers[field.keyName]!.text,
              isExpanded: true, decoration: InputDecoration(labelText: field.label),
              items: {...field.choices!, if (_controllers[field.keyName]!.text.isNotEmpty) _controllers[field.keyName]!.text}
                .map((value) => DropdownMenuItem(value: value, child: ArabicText(value))).toList(),
              onChanged: _saving ? null : (value) => _controllers[field.keyName]!.text = value ?? '',
            ) : TextFormField(controller: _controllers[field.keyName], enabled: !_saving,
              inputFormatters: const [ArabicDigitsFormatter()], textDirection: TextDirection.rtl,
              maxLines: field.lines, readOnly: field.date,
              decoration: InputDecoration(labelText: field.label,
                suffixIcon: field.date ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!field.required) IconButton(tooltip: 'مسح التاريخ', onPressed: _saving ? null : () => _controllers[field.keyName]!.clear(), icon: const Icon(Icons.close)),
                  const Icon(Icons.calendar_today),
                ]) : null),
              onTap: !field.date ? null : () async {
                final parsed = ArabicFormat.parseDate(_controllers[field.keyName]!.text);
                final picked = await showDatePicker(context: context,
                  initialDate: parsed != null && parsed.year >= 1900 && parsed.year < 2200 ? parsed : DateTime.now(),
                  firstDate: DateTime(1900), lastDate: DateTime(2200));
                if (picked != null && mounted) _controllers[field.keyName]!.text = ArabicFormat.date(picked);
              },
              validator: (value) {
                if (field.required && (value == null || value.trim().isEmpty)) return 'هذا الحقل مطلوب';
                if (field.date && value != null && value.trim().isNotEmpty && ArabicFormat.parseDate(value) == null) return 'اختر تاريخًا صحيحًا';
                return null;
              })),
          if (_error != null) ArabicText(_error!, style: const TextStyle(color: AppColors.accentRed)),
        ])))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const ArabicText('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save,
          child: ArabicText(_saving ? 'جارٍ الحفظ…' : 'حفظ')),
      ]));
}
