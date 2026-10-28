import 'package:flutter/material.dart';

import '../../../../core/utils/holiday_sync.dart';
import '../../../../core/widgets/arabic_text.dart';

class HolidaySettingsScreen extends StatefulWidget {
  final HolidaySync? service;
  const HolidaySettingsScreen({super.key, this.service});

  @override
  State<HolidaySettingsScreen> createState() => _HolidaySettingsScreenState();
}

class _HolidaySettingsScreenState extends State<HolidaySettingsScreen> {
  final _key = TextEditingController();
  bool _busy = true;
  bool _configured = false;
  String? _message;
  HolidaySync get _service => widget.service ?? HolidaySync.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final configured = await _service.hasApiKey();
      if (mounted) {
        setState(() {
          _configured = configured;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'تعذر الوصول إلى التخزين الآمن.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy || _key.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.saveApiKey(_key.text);
      if (mounted) _key.clear();
      if (mounted) {
        setState(() {
          _configured = true;
          _message = 'تم التحقق من المفتاح وحفظه. ستُحدّث بيانات الإجازات عند عرض السنة.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'تعذر التحقق من المفتاح. تحقق منه ومن الاتصال أو حد الطلبات، ثم حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.removeApiKey();
      if (mounted) _key.clear();
      if (mounted) {
        setState(() {
          _configured = false;
          _message =
              'تم حذف المفتاح. تبقى بيانات الإجازات المحفوظة محليًا متاحة.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'تعذر حذف المفتاح. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ArabicText('تحديث الإجازات')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ArabicText(
          _configured
              ? 'مفتاح Calendarific محفوظ على هذا الجهاز.'
              : 'أدخل مفتاح Calendarific لتحديث الإجازات.',
        ),
        const SizedBox(height: 8),
        const ArabicText(
          'يُحفظ المفتاح في التخزين الآمن ويُرسل إلى Calendarific عند التحديث. لا تضعه في ملف النسخة الاحتياطية أو تشاركه. تظهر البيانات الخارجية كمواعيد محتملة حتى مراجعة القرار الرسمي.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'مفتاح Calendarific',
            hintText: 'أدخل المفتاح هنا',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const ArabicText('التحقق والحفظ'),
        ),
        if (_configured)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: const ArabicText('حذف المفتاح وإيقاف التحديث المباشر'),
          ),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ArabicText(_message!),
          ),
      ],
    ),
  );
}
