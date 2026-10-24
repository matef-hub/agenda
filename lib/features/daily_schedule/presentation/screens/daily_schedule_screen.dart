import 'package:agenda/core/widgets/arabic_text.dart';

import 'dart:async';

import '../../../../core/utils/arabic_format.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../providers/session_provider.dart';
import 'add_edit_session_screen.dart';

/// الشاشة اليومية للأجندة القضائية
class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  final _deleting = <int>{};
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _pickDate(SessionProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) {
      _searchController.clear();
      provider.setSelectedDate(picked);
    }
  }

  Future<void> _delete(Session session) async {
    if (_deleting.contains(session.id)) return;
    final provider = context.read<SessionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const ArabicText('تأكيد الحذف'),
        content: const ArabicText('هل تريد حذف هذه الجلسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ArabicText('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const ArabicText('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(session.id!));
    final saved = await provider.deleteSession(session.id!);
    if (!mounted) return;
    setState(() => _deleting.remove(session.id));
    if (!saved)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ArabicText(provider.errorMessage ?? 'تعذر حذف الجلسة'),
        ),
      );
  }

  void _changeDate(int days, SessionProvider provider) {
    final newDate = ArabicFormat.shiftDay(provider.selectedDate, days);
    _searchController.clear();
    provider.setSelectedDate(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final selectedDate = provider.selectedDate;
    final sessions = provider.sessions;
    final isLoading = provider.isLoading;

    // تنسيق التواريخ باستخدام AppDateUtils
    final gregorianDay = AppDateUtils.getGregorianDay(selectedDate);
    final gregorianMonth = AppDateUtils.getGregorianMonth(selectedDate);
    final gregorianYear = AppDateUtils.getGregorianYear(selectedDate);
    final hijriDay = AppDateUtils.getHijriDay(selectedDate);
    final hijriMonth = AppDateUtils.getHijriMonth(selectedDate);
    final hijriYear = AppDateUtils.getHijriYear(selectedDate);
    final weekday = AppDateUtils.getWeekday(selectedDate);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- الهيدر العلوي (Header) ---
            _buildHeader(
              gregorianDay: gregorianDay,
              gregorianMonth: gregorianMonth,
              gregorianYear: gregorianYear,
              hijriDay: hijriDay,
              hijriMonth: hijriMonth,
              hijriYear: hijriYear,
              weekday: weekday,
            ),

            // --- شريط التنقل بين الأيام ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.tableBorder, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    tooltip: 'اليوم السابق',
                    onPressed:
                        selectedDate.year <= 1900 &&
                            selectedDate.month == 1 &&
                            selectedDate.day == 1
                        ? null
                        : () => _changeDate(-1, provider),
                    color: AppColors.primaryOlive,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  ArabicText(
                    'جدول الجلسات اليومية',

                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOlive,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    tooltip: 'اليوم التالي',
                    onPressed:
                        selectedDate.year >= 2199 &&
                            selectedDate.month == 12 &&
                            selectedDate.day == 31
                        ? null
                        : () => _changeDate(1, provider),
                    color: AppColors.primaryOlive,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      inputFormatters: const [ArabicDigitsFormatter()],
                      decoration: InputDecoration(
                        hintText: 'بحث في كل الجلسات',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  _searchController.clear();
                                  provider.search('');
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => provider.search(value),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'اختيار تاريخ',
                    onPressed: () => _pickDate(provider),
                    icon: const Icon(Icons.calendar_month),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      provider.setSelectedDate(DateTime.now());
                    },
                    child: const ArabicText('اليوم'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ArabicText(
                  provider.searchQuery.isEmpty
                      ? 'الجلسات: ${sessions.length}'
                      : 'نتائج البحث في كل التواريخ: ${sessions.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
            // --- جدول الجلسات (تصميم الأجندة الورقية) ---
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.errorMessage != null
                  ? _buildErrorState(provider.errorMessage!)
                  : sessions.isEmpty
                  ? _buildEmptyState(provider)
                  : Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primaryOlive,
                          width: 2,
                        ),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          // رأس الجدول
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.tableHeaderGreen,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.primaryOlive,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                _headerCell('المحكمة / الدائرة', flex: 3),
                                _headerCell('الموكل / الخصم', flex: 4),
                                _headerCell('القرار / السابقة', flex: 3),
                              ],
                            ),
                          ),
                          // محتوى الجدول
                          Expanded(
                            child: ListView.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                thickness: 0.5,
                                color: AppColors.tableBorder,
                              ),
                              itemBuilder: (context, index) {
                                return _buildSessionRow(sessions[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_daily_schedule',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddEditSessionScreen(initialDate: provider.selectedDate),
            ),
          );
        },
        backgroundColor: AppColors.primaryOlive,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader({
    required String gregorianDay,
    required String gregorianMonth,
    required String gregorianYear,
    required String hijriDay,
    required String hijriMonth,
    required String hijriYear,
    required String weekday,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.paperCream,
        border: Border(
          bottom: BorderSide(color: AppColors.secondaryGold, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- التاريخ الهجري (يسار) ---
          _buildDateBox(label: 'هجري', day: hijriDay, month: hijriMonth),

          // --- الوسط (اسم اليوم + السنة) ---
          Expanded(
            child: Column(
              children: [
                ArabicText(
                  weekday,

                  style: GoogleFonts.amiri(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ArabicText(
                        hijriYear,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.primaryOlive,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.gavel,
                          size: 20,
                          color: AppColors.accentRed,
                        ),
                      ),
                      ArabicText(
                        gregorianYear,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- التاريخ الميلادي (يمين) ---
          _buildDateBox(
            label: 'ميلادي',
            day: gregorianDay,
            month: gregorianMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildDateBox({
    required String label,
    required String day,
    required String month,
  }) {
    return Container(
      width: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryOlive, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArabicText(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
          const SizedBox(height: 2),
          ArabicText(
            day,

            style: GoogleFonts.amiri(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOlive,
              height: 1.0,
            ),
          ),
          ArabicText(
            month,
            style: const TextStyle(fontSize: 11, color: AppColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: ArabicText(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.amiri(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryOlive,
        ),
      ),
    );
  }

  Widget _buildSessionRow(Session session) {
    return Dismissible(
      key: Key(session.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.accentRed,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _delete(session);
        return false;
      },
      child: InkWell(
        onLongPress: () => _delete(session),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditSessionScreen(
              session: session,
              initialDate: session.sessionDate,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العمود الأول: المحكمة
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (context.read<SessionProvider>().searchQuery.isNotEmpty)
                      ArabicText(
                        ArabicFormat.date(session.sessionDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentRed,
                        ),
                      ),
                    ArabicText(
                      session.courtName,
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ArabicText(
                      session.circuit,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ArabicText(
                      'رقم ${session.caseNumber} لسنة ${session.caseYear}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryOlive,
                      ),
                    ),
                  ],
                ),
              ),
              // فاصل عمودي
              Container(width: 0.5, height: 40, color: AppColors.tableBorder),
              // العمود الثاني: الأطراف
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'موكل: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                            TextSpan(
                              text: ArabicFormat.digits(session.clientName),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'خصم: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                            TextSpan(
                              text: ArabicFormat.digits(session.opponentName),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // فاصل عمودي
              Container(width: 0.5, height: 40, color: AppColors.tableBorder),
              // العمود الثالث: القرار
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (session.decision.isNotEmpty)
                      ArabicText(
                        session.decision,
                        style: GoogleFonts.amiri(
                          fontSize: 12,
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (session.previousSession.isNotEmpty)
                      ArabicText(
                        'س: ${session.previousSession}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    if (session.notes.isNotEmpty)
                      ArabicText(
                        session.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SessionProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: AppColors.tableBorder),
          const SizedBox(height: 16),
          ArabicText(
            provider.searchQuery.isEmpty
                ? 'لا توجد جلسات مسجلة لهذا اليوم'
                : 'لا توجد نتائج للبحث',
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddEditSessionScreen(initialDate: provider.selectedDate),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const ArabicText('إضافة جلسة'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.accentRed),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ArabicText(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.accentRed),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              context.read<SessionProvider>().loadSessions();
            },
            icon: const Icon(Icons.refresh),
            label: const ArabicText('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
