import 'package:flutter/material.dart';

import '../security/secret_vault.dart';
import '../utils/arabic_format.dart';
import 'arabic_text.dart';

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _checking = true, _locked = true, _busy = false;
  String? _error;
  final _password = TextEditingController();
  int _attempts = 0;
  int _generation = 0;
  DateTime? _retryAfter;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final generation = ++_generation;
    try {
      final enabled = await PasswordCipher.hasLock();
      if (mounted && generation == _generation) {
        setState(() {
          _checking = false;
          _locked = enabled;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _locked = true;
          _error = 'تعذر فتح التخزين الآمن. أعد المحاولة.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _generation++;
      _password.clear();
      setState(() {
        _locked = true;
        _checking = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      setState(() => _error = 'انتظر قليلًا قبل المحاولة مرة أخرى.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final generation = _generation;
    try {
      final input = _password.text;
      final normalized = ArabicFormat.normalize(input);
      final correct =
          await PasswordCipher.unlock(input) ||
          (normalized != input && await PasswordCipher.unlock(normalized));
      if (!mounted || generation != _generation) return;
      if (correct) {
        _password.clear();
        _attempts = 0;
        setState(() => _locked = false);
      } else {
        _attempts++;
        if (_attempts >= 5) {
          _retryAfter = DateTime.now().add(const Duration(seconds: 30));
        }
        setState(() => _error = 'كلمة المرور غير صحيحة.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح القفل. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ExcludeFocus(
        excluding: _locked || _checking,
        child: Offstage(
          offstage: _locked || _checking,
          child: TickerMode(
            enabled: !_locked && !_checking,
            child: widget.child,
          ),
        ),
      ),
      if (_locked || _checking)
        Positioned.fill(
          child: Overlay.wrap(
            child: Material(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _checking
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline, size: 48),
                                const SizedBox(height: 16),
                                const ArabicText(
                                  'الأجندة القضائية',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'كلمة المرور',
                                  ),
                                  onSubmitted: (_) => _unlock(),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _busy ? null : _unlock,
                                  child: ArabicText(
                                    _busy ? 'جارٍ الفتح…' : 'فتح الأجندة',
                                  ),
                                ),
                                if (_error != null) ArabicText(_error!),
                                TextButton(
                                  onPressed: _busy ? null : _check,
                                  child: const ArabicText('إعادة المحاولة'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
