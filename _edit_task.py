from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8').replace('setState(() => _dataGeneration++);',"""if (_pageController.hasClients) _pageController.jumpToPage(0);
                          setState(() { _dataGeneration++; _currentIndex = 0; });""")
p.write_text(s,encoding='utf-8')
p=Path('lib/features/daily_schedule/presentation/screens/daily_schedule_screen.dart')
s=p.read_text(encoding='utf-8').replace('    _searchController.clear();\n', '    _debounce?.cancel();\n    _searchController.clear();\n')
s=s.replace("'agenda-${ArabicFormat.dateKey(provider.selectedDate)}.$format'", "'أجندة-${ArabicFormat.digits(ArabicFormat.dateKey(provider.selectedDate))}.$format'")
p.write_text(s,encoding='utf-8')
p=Path('lib/features/settings/presentation/screens/settings_screen.dart')
s=p.read_text(encoding='utf-8').replace("'agenda-${ArabicFormat.dateKey(DateTime.now())}.agenda'", "'أجندة-${ArabicFormat.digits(ArabicFormat.dateKey(DateTime.now()))}.agenda'")
p.write_text(s,encoding='utf-8')
