from pathlib import Path
p=Path('lib/features/daily_schedule/presentation/screens/daily_schedule_screen.dart')
s=p.read_text(encoding='utf-8')
s="import 'dart:async';\nimport '../../../../core/utils/arabic_format.dart';\n"+s
s=s.replace('  void _changeDate(int days, SessionProvider provider) {',"""  final _searchController = TextEditingController();
  Timer? _debounce;
  final _deleting = <int>{};
  @override
  void dispose() { _searchController.dispose(); _debounce?.cancel(); super.dispose(); }
  Future<void> _pickDate(SessionProvider provider) async {
    final picked = await showDatePicker(context: context,
      initialDate: provider.selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2200));
    if (picked != null && mounted) {
      _searchController.clear();
      provider.setSelectedDate(picked);
    }
  }
  Future<void> _delete(Session session) async {
    if (_deleting.contains(session.id)) return;
    final provider = context.read<SessionProvider>();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(title: const Text('تأكيد الحذف'), content: const Text('هل تريد حذف هذه الجلسة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ]));
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(session.id!));
    final saved = await provider.deleteSession(session.id!);
    if (!mounted) return;
    setState(() => _deleting.remove(session.id));
    if (!saved) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.errorMessage ?? 'تعذر حذف الجلسة')));
  }

  void _changeDate(int days, SessionProvider provider) {""")
s=s.replace('provider.selectedDate.add(Duration(days: days))','ArabicFormat.shiftDay(provider.selectedDate, days)')
s=s.replace('    provider.setSelectedDate(newDate);','    _searchController.clear();\n    provider.setSelectedDate(newDate);')
# Search and quick date actions sit above the existing table.
needle='            // --- جدول الجلسات'
pos=s.index(needle)
s=s[:pos]+"""            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(child: TextField(controller: _searchController,
                  inputFormatters: const [ArabicDigitsFormatter()],
                  decoration: InputDecoration(hintText: 'بحث في كل الجلسات', prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty ? null : IconButton(tooltip: 'مسح البحث',
                      onPressed: () { _searchController.clear(); provider.search(''); },
                      icon: const Icon(Icons.close))),
                  onChanged: (value) {
                    setState(() {});
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () => provider.search(value));
                  })),
                IconButton(tooltip: 'اختيار تاريخ', onPressed: () => _pickDate(provider),
                  icon: const Icon(Icons.calendar_month)),
                TextButton(onPressed: () { _searchController.clear(); provider.setSelectedDate(DateTime.now()); },
                  child: const Text('اليوم')),
              ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(alignment: AlignmentDirectional.centerStart,
                child: Text(provider.searchQuery.isEmpty ? 'الجلسات: ${sessions.length}' : 'نتائج البحث في كل التواريخ: ${sessions.length}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)))),
""" + s[pos:]
# Safe swipe: perform deletion before dismissing; return false since provider handles removal.
a=s.index('      confirmDismiss: (direction) async {'); b=s.index('      child: InkWell(',a)
s=s[:a]+"""      confirmDismiss: (_) async { await _delete(session); return false; },
""" +s[b:]
s=s.replace('      child: InkWell(\n        onTap:', '      child: InkWell(\n        onLongPress: () => _delete(session),\n        onTap:')
s=s.replace("TextSpan(text: session.clientName,", "TextSpan(text: ArabicFormat.digits(session.clientName),")
s=s.replace("TextSpan(text: session.opponentName,", "TextSpan(text: ArabicFormat.digits(session.opponentName),")
s=s.replace('fontSize: 9,','fontSize: 11,').replace('fontSize: 10,','fontSize: 11,')
s=s.replace("Text('رقم ${session.caseNumber}/${session.caseYear}',", "Text('رقم ${session.caseNumber} لسنة ${session.caseYear}',")
s=s.replace("                    Text(session.courtName,", """                    if (context.read<SessionProvider>().searchQuery.isNotEmpty)
                      Text(ArabicFormat.date(session.sessionDate), style: const TextStyle(fontSize: 11, color: AppColors.accentRed)),
                    Text(session.courtName,""")
s=s.replace("const Text(\n            'لا توجد جلسات مسجلة لهذا اليوم',", "Text(\n            provider.searchQuery.isEmpty ? 'لا توجد جلسات مسجلة لهذا اليوم' : 'لا توجد نتائج للبحث',")
s=s.replace("onPressed: () => _changeDate(-1, provider),","tooltip: 'اليوم السابق',\n                    onPressed: selectedDate.year <= 1900 && selectedDate.month == 1 && selectedDate.day == 1 ? null : () => _changeDate(-1, provider),")
s=s.replace("onPressed: () => _changeDate(1, provider),","tooltip: 'اليوم التالي',\n                    onPressed: selectedDate.year >= 2199 && selectedDate.month == 12 && selectedDate.day == 31 ? null : () => _changeDate(1, provider),")
p.write_text(s,encoding='utf-8')
# Make all app-owned Text widgets use the single rendering policy.
import re
for p in Path('lib').rglob('*.dart'):
    if p.name in ['arabic_text.dart','record_table_screen.dart']: continue
    s=p.read_text(encoding='utf-8')
    if re.search(r'\bText\(',s):
        s=re.sub(r'\bText\(', 'ArabicText(',s)
        s="import 'package:agenda/core/widgets/arabic_text.dart';\n"+s
        p.write_text(s,encoding='utf-8')
# Date strings themselves are Arabic; parsing/storing stays separate.
p=Path('lib/core/utils/date_utils.dart')
s=p.read_text(encoding='utf-8')
s="import 'arabic_format.dart';\n"+s
s=s.replace("DateFormat('d').format(date)", "ArabicFormat.digits(date.day)")
s=s.replace("DateFormat('yyyy').format(date)", "ArabicFormat.digits(date.year)")
s=s.replace('gregorianToHijri(date).day.toString()', 'ArabicFormat.digits(gregorianToHijri(date).day)')
s=s.replace('gregorianToHijri(date).year.toString()', 'ArabicFormat.digits(gregorianToHijri(date).year)')
s=s.replace("String toString() => '$day $monthName $year هـ';", "String toString() => ArabicFormat.digits('$day $monthName $year هـ');")
s=s.replace('    final jdn = _hijriToJdn(hYear, hMonth, hDay);',"""    if (hYear < 1 || hMonth < 1 || hMonth > 12 || hDay < 1 || hDay > hijriMonthLength(hYear, hMonth)) {
      throw ArgumentError('Invalid Hijri date');
    }
    final jdn = _hijriToJdn(hYear, hMonth, hDay);""")
s=s.replace('    return _jdnToHijri(jdn);',"""    if (jdn < _islamicEpochJdn) throw ArgumentError('Date precedes Hijri epoch');
    return _jdnToHijri(jdn);""")
# Remove unsupported assertion about official Egyptian calendar.
s=s.replace('/// - **Egypt**: Courts and government generally follow the tabular Hijri\n///   calendar, which closely matches this implementation.\n','')
p.write_text(s,encoding='utf-8')
