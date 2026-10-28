import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../security/secret_vault.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_format.dart';
import 'arabic_text.dart';
import 'developer_links.dart';

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _checking = true, _locked = true, _busy = false;
  bool _showIntro = true, _showPassword = false;
  String? _version;
  Timer? _introTimer;
  static const _developer = 'أ/ محمد عاطف';
  String? _error;
  final _password = TextEditingController();
  int _attempts = 0;
  int _generation = 0;
  DateTime? _retryAfter;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _introTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showIntro = false);
    });
    _loadVersion();
    _check();
  }

  Future<void> _loadVersion() async {
    String? version;
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Fallback for platforms where package metadata is unavailable.
    }
    if (version == null || version.isEmpty) {
      try {
        final spec = await rootBundle.loadString('pubspec.yaml');
        version = RegExp(
          r'^version:\s*([^\s+]+)',
          multiLine: true,
        ).firstMatch(spec)?.group(1);
      } catch (_) {
        // Version is optional if the asset is unavailable.
      }
    }
    if (mounted) setState(() => _version = version);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introTimer?.cancel();
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
        excluding: _locked || _checking || _showIntro,
        child: Offstage(
          offstage: _locked || _checking || _showIntro,
          child: TickerMode(
            enabled: !_locked && !_checking && !_showIntro,
            child: widget.child,
          ),
        ),
      ),
      if (_locked || _checking || _showIntro)
        Positioned.fill(
          child: Overlay.wrap(
            child: Material(
              color: AppColors.primaryOliveDark,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF254C37), Color(0xFF0D2519)],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, child) => Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - progress)),
                              child: child,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 116,
                                height: 116,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryGoldLight,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .18,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const ArabicText(
                                'الأجندة القضائية',
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 30,
                                  height: 1.3,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const ArabicText(
                                'كل تفاصيل عملك القانوني في مكان واحد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFC9D8CC),
                                ),
                              ),
                              const SizedBox(height: 26),
                              if (_checking || (_showIntro && !_locked))
                                const CircularProgressIndicator(
                                  color: AppColors.secondaryGoldLight,
                                )
                              else if (_locked)
                                _buildUnlockCard(),
                              const SizedBox(height: 30),
                              Container(
                                width: 36,
                                height: 2,
                                color: AppColors.secondaryGold,
                              ),
                              const SizedBox(height: 14),
                              if (_developer.isNotEmpty)
                                ArabicText(
                                  'برمجة $_developer',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE5EEE7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (_version != null)
                                ArabicText(
                                  'الإصدار ${ArabicFormat.digits(_version!)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFAEC2B2),
                                    fontSize: 11,
                                  ),
                                ),
                              const DeveloperLinks(dark: true),
                            ],
                          ),
                        ),
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

  Widget _buildUnlockCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .12),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppColors.primaryOlive,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArabicText(
                    'مرحبًا بعودتك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  ArabicText(
                    'أدخل رمز القفل لفتح الأجندة',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              tooltip: _showPassword
                  ? 'إخفاء كلمة المرور'
                  : 'إظهار كلمة المرور',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          onSubmitted: (_) => _unlock(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ArabicText(
            _error!,
            style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryOlive,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: ArabicText(
            _busy ? 'جارٍ الفتح…' : 'فتح الأجندة',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (_error != null)
          TextButton(
            onPressed: _busy ? null : _check,
            child: const ArabicText('إعادة المحاولة'),
          ),
      ],
    ),
  );
}
