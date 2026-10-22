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

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
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
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DailyScheduleScreen(),
    const PersonalDataScreen(),
    const PowersOfAttorneyScreen(),
    const BailiffsScreen(),
    const AdminWorkScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryOlive,
        unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'اليومية'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'البيانات'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'التوكيلات'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'المحضرين'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'إدارية'),
        ],
      ),
    );
  }
}
