import 'package:file_picker/file_picker.dart';
import '../../data/repositories/schedule_export.dart';
import 'package:agenda/core/widgets/arabic_text.dart';
import 'dart:async';
import '../../../../core/utils/arabic_format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../providers/session_provider.dart';
import 'add_edit_session_screen.dart';

/// الشاشة اليومية للأجندة القضائية بتصميم Juris Modern
class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  final _deleting = <int>{};
  bool _exporting = false;

  Future<void> _export(String format, SessionProvider provider) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final sessions = List<Session>.from(provider.sessions);
      final bytes = format == 'pdf'
          ? await ScheduleExport.pdf(
              sessions,
              provider.selectedDate,
              searchResults: provider.searchQuery.isNotEmpty,
            )
          : ScheduleExport.calendar(sessions);
      final saved = await FilePicker.saveFile(
        fileName:
            'أجندة-${ArabicFormat.digits(ArabicFormat.dateKey(provider.selectedDate))}.$format',
        bytes: bytes,
        mimeType: format == 'pdf' ? 'application/pdf' : 'text/calendar',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ArabicText(
              format == 'pdf'
                  ? 'تم حفظ الجدول؛ يمكنك طباعته من قارئ الملفات.'
                  : 'تم حفظ ملف التقويم. افتحه في تطبيق التقويم لإضافة المواعيد والتذكير.',
            ),
            backgroundColor: AppColors.brand800,
          ),
        );
      }
    } catch (e) {
      debugPrint('Schedule export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ArabicText('تعذر تصدير الجدول. أعد المحاولة.'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brand800,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      _debounce?.cancel();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const ArabicText('تأكيد الحذف', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
        content: const ArabicText('هل تريد حذف هذه الجلسة بشكل نهائي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ArabicText('إلغاء', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ArabicText(provider.errorMessage ?? 'تعذر حذف الجلسة'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  void _changeDate(int days, SessionProvider provider) {
    final newDate = ArabicFormat.shiftDay(provider.selectedDate, days);
    _debounce?.cancel();
    _searchController.clear();
    provider.setSelectedDate(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final selectedDate = provider.selectedDate;
    final sessions = provider.sessions;
    final isLoading = provider.isLoading;

    // Dates calculations
    final gregorianDay = AppDateUtils.getGregorianDay(selectedDate);
    final gregorianMonth = AppDateUtils.getGregorianMonth(selectedDate);
    final gregorianYear = AppDateUtils.getGregorianYear(selectedDate);
    final hijriDay = AppDateUtils.getHijriDay(selectedDate);
    final hijriMonth = AppDateUtils.getHijriMonth(selectedDate);
    final hijriYear = AppDateUtils.getHijriYear(selectedDate);
    final weekday = AppDateUtils.getWeekday(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.paperCream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // --- Dual Date Card ---
                  _buildDualDateCard(
                    provider,
                    gregorianDay, gregorianMonth, gregorianYear,
                    hijriDay, hijriMonth, hijriYear, weekday,
                  ),
                  const SizedBox(height: 16),

                  // --- Search and Filter Bar ---
                  _buildSearchAndFilterBar(provider, sessions.length),
                  const SizedBox(height: 16),

                  // --- Hearings Table Section ---
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.brand800)),
                    )
                  else if (provider.errorMessage != null)
                    _buildErrorState(provider.errorMessage!)
                  else if (sessions.isEmpty)
                    _buildEmptyState(provider)
                  else
                    _buildHearingsList(sessions),

                  const SizedBox(height: 80), // Padding for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_daily_schedule',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditSessionScreen(initialDate: provider.selectedDate),
            ),
          );
        },
        backgroundColor: AppColors.brand800,
        elevation: 4,
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.secondaryGold.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: AppColors.secondaryGoldLight, size: 20),
        ),
        label: const ArabicText('جلسة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildDualDateCard(
    SessionProvider provider,
    String gDay, String gMonth, String gYear,
    String hDay, String hMonth, String hYear, String weekday
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand100),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand900.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header of card (Navigation)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                color: AppColors.brand700,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _changeDate(-1, provider),
              ),
              InkWell(
                onTap: () => _pickDate(provider),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16, color: AppColors.secondaryGold),
                    const SizedBox(width: 6),
                    const ArabicText('جدول الجلسات اليومية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.brand900)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 20),
                color: AppColors.brand700,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _changeDate(1, provider),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.brand50),
          ),
          // Dates display
          Row(
            children: [
              // Gregorian
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.brand50.withValues(alpha: 0.7),
                    border: Border.all(color: AppColors.brand100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const ArabicText('ميلادي', style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                      ArabicText(gDay, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.brand900, height: 1.2)),
                      ArabicText(gMonth, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand700, height: 1.2)),
                    ],
                  ),
                ),
              ),
              // Center (Weekday and Years)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand100.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.secondaryGold, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const ArabicText('يوم العمل الرسمي', style: TextStyle(fontSize: 11, color: AppColors.brand800, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ArabicText(weekday, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.brand900)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ArabicText('$hYear هـ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand700)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.balance, size: 14, color: AppColors.secondaryGold),
                        ),
                        ArabicText('$gYear م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand700)),
                      ],
                    ),
                  ],
                ),
              ),
              // Hijri
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.brand800,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand900.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const ArabicText('هجري', style: TextStyle(fontSize: 11, color: AppColors.brand200, fontWeight: FontWeight.w500)),
                      ArabicText(hDay, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                      ArabicText(hMonth, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryGoldLight, height: 1.2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(SessionProvider provider, int sessionCount) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand200.withValues(alpha: 0.9)),
                ),
                child: TextField(
                  controller: _searchController,
                  inputFormatters: const [ArabicDigitsFormatter()],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'بحث في كل الجلسات...',
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.brand700),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              provider.search('');
                            },
                          )
                        : null,
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
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                _debounce?.cancel();
                _searchController.clear();
                provider.setSelectedDate(DateTime.now());
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.brand200),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.today, size: 18, color: AppColors.brand700),
                    SizedBox(width: 4),
                    ArabicText('اليوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand800)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: !_exporting && !provider.isLoading,
              onSelected: (value) => _export(value, provider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: ArabicText('حفظ الجدول للطباعة (PDF)')),
                PopupMenuItem(value: 'ics', child: ArabicText('إضافة لتقويم الجهاز (ICS)')),
              ],
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.brand200),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: _exporting
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand800))
                    : const Icon(Icons.ios_share, size: 18, color: AppColors.brand800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                ArabicText(
                  provider.searchQuery.isEmpty ? 'إجمالي القضايا المجدولة لهذا اليوم' : 'نتائج البحث',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand100.withValues(alpha: 0.7),
                border: Border.all(color: AppColors.brand200.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const ArabicText('الجلسات: ', style: TextStyle(fontSize: 12, color: AppColors.brand800, fontWeight: FontWeight.bold)),
                  ArabicText(ArabicFormat.digits(sessionCount.toString()), style: const TextStyle(fontSize: 14, color: AppColors.brand900, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHearingsList(List<Session> sessions) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.brand800,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: const [
                    Icon(Icons.account_balance, size: 14, color: AppColors.secondaryGoldLight),
                    SizedBox(width: 4),
                    ArabicText('المحكمة / الدائرة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand50)),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: const ArabicText('الموكل / الخصم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand50)),
              ),
              Expanded(
                flex: 3,
                child: const ArabicText('القرار / السابقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand50)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // List
        ...sessions.map((session) => _buildSessionCard(session)),
      ],
    );
  }

  Widget _buildSessionCard(Session session) {
    // تحديد لون الإطار الجانبي بناءً على حالة الجلسة (افتراضيات بسيطة)
    Color statusColor = AppColors.brand200;
    if (session.decision.isNotEmpty) {
      statusColor = AppColors.primaryOlive;
    } else if (session.previousSession.isNotEmpty) {
      statusColor = AppColors.accentOrange;
    }

    return Dismissible(
      key: Key(session.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _delete(session);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand100),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand900.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الشريط الجانبي الملون
                Container(width: 4, color: statusColor),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. المحكمة والدائرة
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (context.read<SessionProvider>().searchQuery.isNotEmpty)
                                    ArabicText(
                                      ArabicFormat.date(session.sessionDate),
                                      style: const TextStyle(fontSize: 10, color: AppColors.accentRed, fontWeight: FontWeight.bold),
                                    ),
                                  ArabicText(
                                    session.courtName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brand900, height: 1.2),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand50,
                                      border: Border.all(color: AppColors.brand100),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ArabicText(
                                      session.circuit,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brand800),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ArabicText(
                                    'رقم ${ArabicFormat.digits(session.caseNumber)} لسنة ${ArabicFormat.digits(session.caseYear.toString())}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),

                            // 2. الموكل والخصم
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: const BoxDecoration(
                                  border: Border(right: BorderSide(color: AppColors.brand50)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ArabicText('الموكل', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w600)),
                                    ArabicText(session.clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand900), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    const ArabicText('الخصم', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w600)),
                                    ArabicText(session.opponentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),

                            // 3. القرار وتاريخ الجلسة السابقة
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (session.decision.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow,
                                        border: Border.all(color: AppColors.surfaceContainer),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: ArabicText(
                                        session.decision,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brand800),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                  if (session.previousSession.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const ArabicText('سابق الجلسة:', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w600)),
                                    ArabicText(
                                      session.previousSession,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Action Footer
                        if (session.notes.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: AppColors.brand50),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.notes, size: 14, color: AppColors.brand200),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ArabicText(
                                  session.notes,
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SessionProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppColors.brand50.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.brand200, style: BorderStyle.none), // Using dashed visually normally, fallback to clear
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ArabicText(
            provider.searchQuery.isEmpty ? 'لا توجد جلسات مسجلة لهذا اليوم' : 'لا توجد نتائج للبحث',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brand700),
          ),
          const SizedBox(height: 4),
          const ArabicText(
            'اضغط على زر الجلسة الجديدة أدناه لإدراج جلسة جديدة أو تعديل الرول.',
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: 16),
          ArabicText(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.accentRed, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => context.read<SessionProvider>().loadSessions(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const ArabicText('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
