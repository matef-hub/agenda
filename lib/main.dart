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
import 'features/personal_data/presentation/screens/personal_data_screen.dart';
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الأجندة القضائية',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
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

  final List<String> _titles = [
    'الجلسات اليومية',
    'البيانات الشخصية',
    'التوكيلات',
    'المحضرين',
    'الأعمال الإدارية',
  ];

  final List<Widget> _screens = [
    const DailyScheduleScreen(),
    const PersonalDataScreen(),
    const PowersOfAttorneyScreen(),
    const BailiffsScreen(),
    const AdminWorkScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
      backgroundColor: AppColors.paperCream,
      body: SafeArea(
        child: Column(
          children: [
            // شريط العنوان الأنيق
            _buildMinimalistHeader(),
            // التنقل بالإيماءات (Swipe)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: _screens,
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
                  _titles[_currentIndex],
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
          // مؤشر التنقل السريع (نقاط قابلة للضغط)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _screens.length,
              (index) => _buildNavDot(index),
            ),
          ),
        ],
      ),
    );
  }

  /// نقاط التنقل النقية
  Widget _buildNavDot(int index) {
    final isActive = index == _currentIndex;
    return GestureDetector(
      onTap: () => _navigateToPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: isActive ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryOlive
              : AppColors.primaryOlive.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
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
