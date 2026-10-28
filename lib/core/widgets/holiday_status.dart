import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/arabic_format.dart';
import '../utils/egypt_holidays.dart';
import '../utils/holiday_sync.dart';
import 'arabic_text.dart';

class HolidayStatus extends StatefulWidget {
  final DateTime date;
  final bool compact;
  final HolidaySync? service;
  const HolidayStatus({
    super.key,
    required this.date,
    this.compact = false,
    this.service,
  });

  @override
  State<HolidayStatus> createState() => _HolidayStatusState();
}

class _HolidayStatusState extends State<HolidayStatus> with WidgetsBindingObserver {
  late Future<HolidaySnapshot?> _snapshot;
  HolidaySync get _service => widget.service ?? HolidaySync.instance;

  void _refresh() {
    if (mounted) setState(() => _snapshot = _service.forYear(widget.date.year));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapshot = _service.forYear(widget.date.year);
    _service.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant HolidayStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.service != widget.service) {
      if (oldWidget.service != widget.service) {
        (oldWidget.service ?? HolidaySync.instance).removeListener(_refresh);
        _service.addListener(_refresh);
      }
      _snapshot = _service.forYear(widget.date.year);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = EgyptHolidays.forDate(widget.date);
    return FutureBuilder<HolidaySnapshot?>(
      future: _snapshot,
      builder: (context, snapshot) {
        final remoteName =
            snapshot.data?.holidays[ArabicFormat.dateKey(widget.date)];
        final useRemote =
            remoteName != null && local.kind != EgyptDayKind.officialHoliday;
        final label = useRemote
            ? 'مناسبة محتملة — تحقق من القرار'
            : local.label;
        final name = useRemote ? remoteName : local.holidayName;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArabicText(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.compact ? 10 : 11,
                color: AppColors.brand800,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (name != null)
              ArabicText(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textLight,
                ),
              ),
            if (useRemote && snapshot.data != null)
              ArabicText(
                  'المصدر: Calendarific — ${ArabicFormat.date(snapshot.data!.fetchedAt)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: AppColors.textLight),
              ),
          ],
        );
      },
    );
  }
}
