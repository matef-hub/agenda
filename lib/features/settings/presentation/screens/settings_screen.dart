import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/security/backup_service.dart';
import '../../../../core/security/secret_vault.dart';
import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/arabic_text.dart';

Future<String?> askPassword(
  BuildContext context, {
  required String title,
  bool confirm = false,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PasswordDialog(title: title, confirm: confirm),
);

class _PasswordDialog extends StatefulWidget {
  final String title;
  final bool confirm;
  const _PasswordDialog({required this.title, required this.confirm});
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: ArabicText(widget.title),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              validator: (v) => (v?.length ?? 0) < (widget.confirm ? 10 : 1)
                  ? 'أدخل كلمة مرور${widget.confirm ? ' من ١٠ أحرف على الأقل' : ''}'
                  : null,
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmation,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                ),
                validator: (v) =>
                    v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
              ),
              const SizedBox(height: 8),
              const ArabicText(
                'احتفظ بكلمة المرور في مكان آمن؛ لن يمكن استعادتها عند نسيانها.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const ArabicText('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _password.text);
          }
        },
        child: const ArabicText('متابعة'),
      ),
    ],
  );
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onRestored;
  const SettingsScreen({super.key, this.onRestored});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backup = BackupService(DatabaseHelper());
  bool _busy = false, _restored = false;
  String? _message;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      debugPrint('Settings action failed: ${e.runtimeType}');
      if (mounted) {
        setState(
          () => _message = 'تعذر إتمام العملية. تحقق من كلمة المرور والملف أو صلاحية الحفظ، ثم أعد المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final password = await askPassword(
      context,
      title: 'كلمة مرور النسخة الاحتياطية',
      confirm: true,
    );
    if (password == null) return;
    await _run(() async {
      final bytes = Uint8List.fromList(
        utf8.encode(await _backup.export(password)),
      );
      final path = await FilePicker.saveFile(
        dialogTitle: 'حفظ نسخة احتياطية مشفرة',
        fileName: 'أجندة-${ArabicFormat.digits(ArabicFormat.dateKey(DateTime.now()))}.agenda',
        bytes: bytes,
      );
      if (mounted && path != null) {
        setState(() => _message = 'تم حفظ النسخة الاحتياطية المشفرة بنجاح.');
      }
    });
  }

  Future<void> _restore() async {
    await _run(() async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['agenda'],
      );
      if (file == null || !mounted) return;
      final size = await file.length();
      if (size != null && size > 50 * 1024 * 1024) {
        throw const FormatException('File too large');
      }
      if (!mounted) return;
      final password = await askPassword(
        context,
        title: 'فتح النسخة الاحتياطية',
      );
      if (password == null) return;
      final tables = await _backup.read(
        utf8.decode(await file.readAsBytes()),
        password,
      );
      if (!mounted) return;
      final count = tables.values.fold<int>(
        0,
        (sum, rows) => sum + rows.length,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const ArabicText('استعادة البيانات'),
          content: ArabicText(
            'تحتوي النسخة على $count سجلًا. ستستبدل كل البيانات الحالية. احفظ نسخة من بياناتك الحالية أولًا إذا كنت تحتاجها. هل تريد الاستعادة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const ArabicText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const ArabicText('استعادة واستبدال'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _backup.restore(tables);
      widget.onRestored?.call();
      if (mounted) {
        setState(() {
          _restored = true;
          _message = 'تمت الاستعادة بنجاح. ارجع للأجندة لعرض البيانات.';
        });
      }
    });
  }

  Future<void> _lock(bool enable) async {
    try {
      if (enable && await PasswordCipher.hasLock()) {
        if (!mounted) return;
        final current = await askPassword(
          context,
          title: 'كلمة المرور الحالية',
        );
        if (current == null) return;
        if (!await PasswordCipher.unlock(current)) {
          if (mounted) {
            setState(() => _message = 'كلمة المرور الحالية غير صحيحة.');
          }
          return;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر فتح التخزين الآمن.');
      return;
    }
    if (!mounted) return;
    final password = await askPassword(
      context,
      title: enable ? 'تفعيل قفل التطبيق' : 'كلمة المرور الحالية',
      confirm: enable,
    );
    if (password == null) return;
    await _run(() async {
      if (enable) {
        await PasswordCipher.setLock(password);
      } else {
        await PasswordCipher.removeLock(password);
      }
      if (mounted) {
        setState(
          () => _message = enable
              ? 'تم تفعيل القفل عند فتح التطبيق والعودة من الخلفية.'
              : 'تم إلغاء قفل التطبيق.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const ArabicText('الحماية والنسخ الاحتياطي'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: _busy ? null : () => Navigator.pop(context, _restored),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ArabicText(
            'النسخ الاحتياطي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const ArabicText(
            'احفظ نسخة مشفرة خارج الجهاز، واستخدم كلمة مرور تحتفظ بها لاستعادتها.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.save_alt),
            label: const ArabicText('حفظ نسخة احتياطية'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const ArabicText('استعادة نسخة احتياطية'),
          ),
          const Divider(height: 32),
          const ArabicText(
            'قفل التطبيق',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const ArabicText(
            'يطلب كلمة المرور عند الفتح والعودة من الخلفية. احتفظ بها؛ النسخ الاحتياطية لا تشمل كلمة مرور القفل.',
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _lock(true),
            child: const ArabicText('تفعيل أو تغيير كلمة المرور'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _lock(false),
            child: const ArabicText('إلغاء القفل بكلمة المرور الحالية'),
          ),
          const Divider(height: 32),
          const ArabicText(
            'التاريخ الهجري حسابي وقد يختلف عن التقويم الرسمي. جميع تواريخ المواعيد تُحفظ بالتقويم الميلادي.',
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ArabicText(_message!),
            ),
        ],
      ),
    ),
  );
}
