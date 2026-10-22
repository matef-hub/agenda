import 'package:flutter/material.dart';
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
  void _changeDate(int days, SessionProvider provider) {
    final newDate = provider.selectedDate.add(Duration(days: days));
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryOlive.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    onPressed: () => _changeDate(-1, provider),
                    color: AppColors.primaryOlive,
                  ),
                  const Text(
                    'جدول الجلسات اليومية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOlive,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => _changeDate(1, provider),
                    color: AppColors.primaryOlive,
                  ),
                ],
              ),
            ),

            // --- جدول الجلسات ---
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.errorMessage != null
                      ? _buildErrorState(provider.errorMessage!)
                      : sessions.isEmpty
                          ? _buildEmptyState(provider)
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                return _buildSessionCard(sessions[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditSessionScreen(
                initialDate: provider.selectedDate,
              ),
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
            bottom: BorderSide(color: AppColors.secondaryGold, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- التاريخ الهجري (يسار) ---
          _buildDateBox(
            label: 'هجري',
            day: hijriDay,
            month: hijriMonth,
          ),

          // --- الوسط (اسم اليوم + السنة) ---
          Expanded(
            child: Column(
              children: [
                Text(
                  weekday,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hijriYear,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.primaryOlive,
                          fontWeight: FontWeight.bold),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.gavel,
                          size: 20, color: AppColors.accentRed),
                    ),
                    Text(
                      gregorianYear,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
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
          Text(
            label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
          const SizedBox(height: 2),
          Text(
            day,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOlive,
            ),
          ),
          Text(
            month,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    return Dismissible(
      key: Key(session.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.accentRed,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل أنت متأكد من حذف هذه الجلسة؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('حذف',
                      style: TextStyle(color: AppColors.accentRed))),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<SessionProvider>().deleteSession(session.id!);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          side:
              const BorderSide(color: AppColors.tableBorder, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditSessionScreen(
                  session: session,
                  initialDate: session.sessionDate,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف الأول: المحكمة والدائرة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المحكمة / الدائرة',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Text(
                            '${session.courtName}\n${session.circuit}\nرقم ${session.caseNumber} لسنة ${session.caseYear}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primaryOlive),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // الموكل
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الموكل',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Text(
                              '${session.clientName}\n(${session.clientCapacity})',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // الخصم
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الخصم',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Text(
                              '${session.opponentName}\n(${session.opponentCapacity})',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                // الصف الثاني: القرار والملاحظات (إن وجدت)
                if (session.previousSession.isNotEmpty ||
                    session.decision.isNotEmpty) ...[
                  const Divider(height: 16),
                  Row(
                    children: [
                      if (session.previousSession.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('السابقة',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textLight)),
                              Text(session.previousSession,
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      if (session.decision.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accentRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            session.decision,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accentRed,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
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
          const Text(
            'لا توجد جلسات مسجلة لهذا اليوم',
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditSessionScreen(
                    initialDate: provider.selectedDate,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة جلسة'),
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
            child: Text(
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
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
