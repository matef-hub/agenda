import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/security/secret_vault.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/arabic_text.dart';

class PersonalDataScreen extends StatefulWidget {
  final DatabaseHelper? database;
  const PersonalDataScreen({super.key, this.database});
  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  static const _fields = {
    'name': 'اسم المحامي',
    'home_address': 'عنوان المنزل',
    'office_address': 'عنوان المكتب',
    'home_tel': 'تليفون المنزل',
    'office_tel': 'تليفون المكتب',
    'mobile': 'رقم الموبايل',
    'id_card_no': 'الرقم القومي',
    'passport_no': 'رقم جواز السفر',
    'car_license_no': 'رقم رخصة السيارة',
    'driving_license_no': 'رقم رخصة القيادة',
    'bank_account_no': 'رقم الحساب البنكي',
    'credit_card_no': 'رقم كارت الائتمان (اختياري)',
    'email': 'البريد الإلكتروني',
  };
  late final _db = widget.database ?? DatabaseHelper();
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final key in _fields.keys) key: TextEditingController(),
  };
  bool _loading = true, _saving = false, _reveal = false, _dirty = false;
  String? _error;
  int? _id;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _db.queryAll('personal_info');
      if (!mounted) return;
      final row = rows.isEmpty ? <String, dynamic>{} : rows.first;
      for (final key in _fields.keys) {
        _controllers[key]!.text = ArabicFormat.digits(row[key] ?? '');
      }
      setState(() {
        _id = row['id'] as int?;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      debugPrint('Personal data load failed: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل البيانات الشخصية. أعد المحاولة.';
        });
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _error != null ||
        !(_form.currentState?.validate() ?? false))
      return;
    setState(() => _saving = true);
    try {
      final row = <String, dynamic>{
        for (final key in _fields.keys)
          key: ArabicFormat.normalize(_controllers[key]!.text.trim()),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final id = _id;
      if (id == null) {
        final inserted = await _db.insert('personal_info', row);
        if (mounted) _id = inserted;
      } else if (await _db.update('personal_info', row, id) != 1) {
        throw StateError('Missing record');
      }
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: ArabicText('تم حفظ البيانات بنجاح')),
        );
      }
    } catch (e) {
      debugPrint('Personal data save failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ArabicText(
              'تعذر الحفظ. بياناتك ما زالت موجودة؛ أعد المحاولة.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validate(String key, String? value) {
    final text = ArabicFormat.normalize(value?.trim() ?? '');
    if (text.isEmpty) return null;
    if (key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text))
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    if (['home_tel', 'office_tel', 'mobile'].contains(key) &&
        !RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(text))
      return 'أدخل رقم هاتف صحيحًا';
    if (key == 'id_card_no' && !RegExp(r'^\d{14}$').hasMatch(text))
      return 'الرقم القومي مكوّن من ١٤ رقمًا';
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const ArabicText('البيانات الشخصية'),
      actions: [
        IconButton(
          tooltip: 'حفظ البيانات',
          onPressed: _loading || _saving || _error != null ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
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
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 56,
                  color: AppColors.primaryOlive,
                ),
                const SizedBox(height: 12),
                if (_dirty)
                  const ArabicText(
                    'توجد تعديلات لم تُحفظ',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const ArabicText('إظهار البيانات الحساسة'),
                  value: _reveal,
                  onChanged: (value) => setState(() => _reveal = value),
                ),
                for (final entry in _fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _controllers[entry.key],
                      enabled: !_saving,
                      inputFormatters: const [ArabicDigitsFormatter()],
                      obscureText:
                          SecretVault.sensitive.contains(entry.key) && !_reveal,
                      enableSuggestions: !SecretVault.sensitive.contains(
                        entry.key,
                      ),
                      autocorrect: false,
                      textDirection: entry.key == 'email'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      keyboardType: entry.key == 'email'
                          ? TextInputType.emailAddress
                          : [
                              'mobile',
                              'office_tel',
                              'home_tel',
                            ].contains(entry.key)
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: entry.value),
                      onChanged: (_) {
                        if (!_dirty) setState(() => _dirty = true);
                      },
                      validator: (value) => _validate(entry.key, value),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: ArabicText(_saving ? 'جارٍ الحفظ…' : 'حفظ البيانات'),
                ),
              ],
            ),
          ),
  );
}
