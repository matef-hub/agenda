import 'core/utils/agenda_localizations.dart';
import 'core/widgets/app_lock.dart';
import 'core/security/backup_reminder.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

import 'package:agenda/core/widgets/arabic_text.dart';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/daily_schedule/presentation/providers/session_provider.dart';
import 'features/daily_schedule/presentation/screens/daily_schedule_screen.dart';
import 'features/powers_of_attorney/presentation/screens/powers_of_attorney_screen.dart';
import 'features/bailiffs/presentation/screens/bailiffs_screen.dart';
import 'features/admin_work/presentation/screens/admin_work_screen.dart';

// إصلاح مشكلة SQLite على الويب
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> main() async {
  // تهيئة قاعدة البيانات لجميع المنصات (يجب أن تكون async للويب)
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // استخدام SQLite Web FFI للويب
    // تجنب مشكلة SharedWorker في وضع التصحيح باستخدام التنفيذ المباشر
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool enableLock;
  const MyApp({super.key, this.enableLock = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الأجندة القضائية',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: enableLock ? AppLock(child: child!) : child!,
      ),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        AgendaLocalizationsDelegate(),
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const JudicialAgendaShell(),
    );
  }
}

/// الواجهة الرئيسية الجديدة - تصميم نقي بالإيماءات
class JudicialAgendaShell extends StatefulWidget {
  const JudicialAgendaShell({super.key});

  @override
  State<JudicialAgendaShell> createState() => _JudicialAgendaShellState();
}

class _JudicialAgendaShellState extends State<JudicialAgendaShell> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int _dataGeneration = 0;
  bool _backupNoticeDismissed = false;
  late Future<DateTime?> _lastBackup;

  final List<String> _titles = [
    'الجلسات اليومية',
    'التوكيلات',
    'أوراق المحضرين',
    'الأعمال الإدارية',
  ];

  final List<Widget> _screens = [
    const DailyScheduleScreen(),
    const PowersOfAttorneyScreen(),
    const BailiffsScreen(),
    const AdminWorkScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _lastBackup = BackupReminder.lastSaved();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.paperCream,
      body: SafeArea(
        child: Column(
          children: [
            // شريط العنوان الأنيق
            _buildMinimalistHeader(),
            if (!_backupNoticeDismissed)
              FutureBuilder<DateTime?>(
                future: _lastBackup,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      snapshot.hasError ||
                      !BackupReminder.due(snapshot.data, DateTime.now())) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: const Color(0xFFFFF4E1),
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.backup_outlined,
                          color: AppColors.secondaryGold,
                        ),
                        title: const ArabicText(
                          'تذكير بالنسخ الاحتياطي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: const ArabicText(
                          'احفظ نسخة مشفرة من الإعدادات.',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          tooltip: 'إخفاء التذكير',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _backupNoticeDismissed = true),
                        ),
                      ),
                    ),
                  );
                },
              ),
            // التنقل بالإيماءات (Swipe)
            Expanded(
              child: PageView(
                key: ValueKey(_dataGeneration),
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: _screens
                    .map((screen) => _KeepAlivePage(child: screen))
                    .toList(),
              ),
            ),
            // مؤشر الصفحات السفلي
            _buildPageIndicator(),
          ],
        ),
      ),
    );
  }

  /// الهيدر النقي - بدون أزرار، فقط عنوان ومؤشرات تنقل خفية
  Widget _buildMinimalistHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined),
                label: const ArabicText('الإعدادات'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        onRestored: () {
                          if (!mounted) return;
                          context.read<SessionProvider>().loadSessions();
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                          setState(() {
                            _dataGeneration++;
                            _currentIndex = 0;
                          });
                        },
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _lastBackup = BackupReminder.lastSaved();
                      _backupNoticeDismissed = false;
                    });
                  }
                },
              ),
              // الخط الذهبي الأيسر
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.secondaryGold, AppColors.primaryOlive],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // العنوان بخط أميري
              Expanded(
                child: ArabicText(
                  'الأجندة القضائية',
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOlive,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _titles.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: ArabicText(
                      _titles[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _currentIndex == index,
                    onSelected: (_) => _navigateToPage(index),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// مؤشر الصفحات السفلي (خط ذهبي رفيع)
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 60,
        height: 2,
        decoration: BoxDecoration(
          color: AppColors.secondaryGold.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
