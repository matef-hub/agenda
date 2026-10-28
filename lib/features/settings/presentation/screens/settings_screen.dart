import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/reports/report_action.dart';
import '../../../../core/security/backup_service.dart';
import '../../../../core/security/backup_reminder.dart';
import '../../../../core/security/secret_vault.dart';
import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/widgets/developer_links.dart';
import '../../../personal_data/presentation/screens/personal_data_screen.dart';

Future<String?> askPassword(
  BuildContext context, {
  required String title,
  bool confirm = false,
  bool pin = false,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PasswordDialog(title: title, confirm: confirm, pin: pin),
);

class _PasswordDialog extends StatefulWidget {
  final String title;
  final bool confirm;
  final bool pin;
  const _PasswordDialog({
    required this.title,
    required this.confirm,
    required this.pin,
  });
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
              keyboardType: widget.pin
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              validator: (v) =>
                  widget.pin &&
                      !RegExp(r'^[0-9]{4}$')
                          .hasMatch(ArabicFormat.normalize(v ?? ''))
                  ? 'أدخل رمزًا من ٤ أرقام'
                  : (v?.length ?? 0) < (widget.confirm && !widget.pin ? 10 : 1)
                  ? 'أدخل كلمة مرور${widget.confirm ? ' من ١٠ أحرف على الأقل' : ''}'
                  : null,
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmation,
                obscureText: true,
                autocorrect: false,
                keyboardType: widget.pin
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                ),
                validator: (v) =>
                    ArabicFormat.normalize(v ?? '') !=
                        ArabicFormat.normalize(_password.text)
                    ? 'كلمتا المرور غير متطابقتين'
                    : null,
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
            Navigator.pop(
              context,
              widget.pin
                  ? ArabicFormat.normalize(_password.text)
                  : _password.text,
            );
          }
        },
        child: const ArabicText('متابعة'),
      ),
    ],
  );
}

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onRestored;
  final DatabaseHelper? database;
  const SettingsScreen({super.key, this.onRestored, this.database});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ArabicText('الإعدادات')),
    body: ListView(
      children: [
        const ListTile(
          leading: Icon(Icons.code),
          title: ArabicText('برمجة أ/ محمد عاطف'),
          subtitle: DeveloperLinks(),
        ),
        ListTile(
          leading: const Icon(Icons.print_outlined),
          title: const ArabicText('تصدير البيانات للطباعة'),
          subtitle: const ArabicText('كل الأقسام أو قسم واحد'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => exportOfficeReport(context, database: database),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const ArabicText('البيانات الشخصية'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalDataScreen(database: database),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const ArabicText('حماية التطبيق'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _SettingsToolsScreen(protection: true),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const ArabicText('النسخ الاحتياطي والاستعادة'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _SettingsToolsScreen(
                protection: false,
                onRestored: onRestored,
                database: database,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsToolsScreen extends StatefulWidget {
  final bool protection;
  final VoidCallback? onRestored;
  final DatabaseHelper? database;
  const _SettingsToolsScreen({
    required this.protection,
    this.onRestored,
    this.database,
  });
  @override
  State<_SettingsToolsScreen> createState() => _SettingsToolsScreenState();
}

class _SettingsToolsScreenState extends State<_SettingsToolsScreen> {
  late final _backup = BackupService(widget.database ?? DatabaseHelper());
  bool _busy = false, _restored = false;
  String? _message;
  DateTime? _lastBackup;
  bool _backupDateAvailable = false;

  @override
  void initState() {
    super.initState();
    if (!widget.protection) _loadBackupDate();
  }

  Future<void> _loadBackupDate() async {
    try {
      final value = await BackupReminder.lastSaved();
      if (mounted) {
        setState(() {
          _lastBackup = value;
          _backupDateAvailable = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backupDateAvailable = false);
    }
  }

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
        fileName:
            'أجندة-${ArabicFormat.digits(ArabicFormat.dateKey(DateTime.now()))}.agenda',
        bytes: bytes,
      );
      if (path != null) {
        final now = DateTime.now();
        var recorded = true;
        try {
          await BackupReminder.recordSaved(now);
        } catch (_) {
          recorded = false;
        }
        if (mounted) {
          setState(() {
            _lastBackup = recorded ? now : _lastBackup;
            _backupDateAvailable = recorded;
            _message = recorded
                ? 'تم حفظ النسخة الاحتياطية المشفرة بنجاح.'
                : 'تم حفظ النسخة، لكن تعذر تسجيل تاريخها على الجهاز.';
          });
        }
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
      const labels = {
        'sessions': 'الجلسات اليومية',
        'powers_of_attorney': 'التوكيلات',
        'bailiff_papers': 'أوراق المحضرين',
        'admin_notes': 'الأعمال الإدارية',
        'personal_info': 'البيانات الشخصية',
      };
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const ArabicText('اختر ما تريد استعادته'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'all'),
              child: const ArabicText('كل الأقسام'),
            ),
            for (final entry in labels.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.key),
                child: ArabicText(entry.value),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ArabicText('إلغاء'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      final selected = choice == 'all'
          ? DatabaseHelper.tables.toSet()
          : {choice};
      final count = selected
          .map((table) => tables[table]!)
          .fold<int>(0, (sum, rows) => sum + rows.length);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const ArabicText('استعادة البيانات'),
          content: ArabicText(
            'سيتم استعادة ${choice == 'all' ? 'كل الأقسام' : labels[choice]} ($count سجلًا) واستبدال البيانات الحالية في ${choice == 'all' ? 'كل الأقسام' : 'هذا القسم'}، حتى إذا كان فارغًا في النسخة. احفظ نسخة من بياناتك الحالية أولًا إذا كنت تحتاجها. هل تريد الاستعادة؟',
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
      await _backup.restore(tables, selectedTables: selected);
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
      pin: enable,
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
        title: ArabicText(
          widget.protection ? 'حماية التطبيق' : 'النسخ الاحتياطي والاستعادة',
        ),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: _busy ? null : () => Navigator.pop(context, _restored),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.protection) ...[
            const ArabicText(
              'احفظ نسخة مشفرة خارج الجهاز، واستخدم كلمة مرور تحتفظ بها لاستعادتها.',
            ),
            if (_backupDateAvailable)
              ArabicText(
                _lastBackup == null
                    ? 'لم يُسجّل حفظ نسخة احتياطية على هذا الجهاز بعد.'
                    : 'آخر نسخة محفوظة على هذا الجهاز: ${ArabicFormat.date(_lastBackup!)}',
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
          ],
          if (widget.protection) ...[
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
          ],
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
