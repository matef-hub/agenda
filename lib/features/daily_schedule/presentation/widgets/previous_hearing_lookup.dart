import 'package:flutter/material.dart';

import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/models/hearing_suggestion.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

class PreviousHearingLookup extends StatefulWidget {
  final String number, year;
  final DateTime date;
  final SessionRepository repository;
  final ValueChanged<Session> onUse;
  final bool enabled;

  const PreviousHearingLookup({
    super.key,
    required this.number,
    required this.year,
    required this.date,
    required this.repository,
    required this.onUse,
    this.enabled = true,
  });

  @override
  State<PreviousHearingLookup> createState() => _PreviousHearingLookupState();
}

class _PreviousHearingLookupState extends State<PreviousHearingLookup>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<HearingSuggestion> _suggestions = [];
  HearingSuggestion? _selected;
  bool _loading = false, _searched = false;
  String? _error;
  int _request = 0;

  String _normalized(String value) => ArabicFormat.normalize(value).trim();

  @override
  void didUpdateWidget(covariant PreviousHearingLookup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_normalized(widget.number) != _normalized(oldWidget.number) ||
        _normalized(widget.year) != _normalized(oldWidget.year) ||
        widget.repository != oldWidget.repository) {
      _clear();
    }
  }

  void _clear() {
    _request++;
    _suggestions = [];
    _selected = null;
    _loading = false;
    _searched = false;
    _error = null;
  }

  Future<void> _lookup() async {
    final number = widget.number;
    final year = widget.year;
    final parsedYear = int.tryParse(_normalized(year));
    if (_normalized(number).isEmpty ||
        parsedYear == null ||
        parsedYear < 1800 ||
        parsedYear > 2200) {
      setState(() => _error = 'أدخل رقم الدعوى وسنة صحيحة لاسترجاع البيانات.');
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _searched = true;
      _selected = null;
      _suggestions = [];
      _error = null;
    });
    try {
      final result = await widget.repository.findPreviousHearings(number, year);
      if (!mounted ||
          request != _request ||
          _normalized(widget.number) != _normalized(number) ||
          _normalized(widget.year) != _normalized(year)) {
        return;
      }
      setState(() => _suggestions = result);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = 'تعذر استرجاع البيانات السابقة. يمكنك إعادة المحاولة أو الإدخال والحفظ يدويًا.',
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _details(Session hearing) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ArabicText('رقم ${hearing.caseNumber} لسنة ${hearing.caseYear}'),
      ArabicText('المحكمة: ${hearing.courtName} — الدائرة: ${hearing.circuit}'),
      ArabicText('الموكل: ${hearing.clientName}'),
      ArabicText('الخصم: ${hearing.opponentName}'),
      ArabicText(
        'تاريخ الجلسة المحفوظة: ${ArabicFormat.date(hearing.sessionDate)}',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selected = _selected;
    final decision = selected?.lastDecisionBefore(widget.date);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArabicText(
              selected == null
                  ? 'بيانات من جلسات محفوظة'
                  : 'مصدر البيانات المختار',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (selected == null) ...[
              const ArabicText(
                'اختياري: تُملأ الحقول الفارغة فقط، وتظل البيانات التي كتبتها كما هي.',
                style: TextStyle(fontSize: 12),
              ),
              OutlinedButton.icon(
                key: const ValueKey('retrieve-hearing'),
                onPressed: widget.enabled && !_loading ? _lookup : null,
                icon: const Icon(Icons.manage_search),
                label: const ArabicText('استرجاع البيانات السابقة'),
              ),
            ],
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ArabicText(_error!),
            if (_searched &&
                !_loading &&
                _error == null &&
                _suggestions.isEmpty)
              const ArabicText(
                'لا توجد جلسات محفوظة بنفس الرقم والسنة. يمكنك إدخال البيانات يدويًا.',
              ),
            if (selected == null && _suggestions.isNotEmpty) ...[
              ArabicText(
                _suggestions.length == 1
                    ? 'بيانات مطابقة — اختر استخدامها أو أكمل يدويًا'
                    : 'توجد ${_suggestions.length} نتائج مختلفة — اختر البيانات المناسبة',
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _details(suggestion.latest),
                        TextButton(
                          key: ValueKey('use-hearing-${suggestion.latest.id}'),
                          onPressed: widget.enabled
                              ? () {
                                  widget.onUse(suggestion.latest);
                                  setState(() => _selected = suggestion);
                                }
                              : null,
                          child: const ArabicText('استخدام هذه البيانات'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            if (selected != null) ...[
              const ArabicText(
                'تم ملء الحقول الفارغة فقط؛ يمكنك تعديل البيانات.',
                style: TextStyle(fontSize: 12),
              ),
              _details(selected.latest),
              TextButton(
                onPressed: widget.enabled
                    ? () => setState(() => _selected = null)
                    : null,
                child: const ArabicText('عرض الاقتراحات مرة أخرى'),
              ),
              const Divider(),
              const ArabicText(
                'آخر قرار مسجل قبل تاريخ الجلسة الجديدة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (decision == null)
                const ArabicText('لا يوجد قرار سابق مسجل')
              else ...[
                ArabicText('بتاريخ ${ArabicFormat.date(decision.sessionDate)}'),
                ArabicText(
                  decision.decision,
                  key: const ValueKey('previous-decision'),
                ),
              ],
              const ArabicText('للاطلاع فقط — لا يُنسخ إلى حقل القرار الحالي.'),
            ],
            if (_suggestions.isNotEmpty)
              TextButton(
                onPressed: widget.enabled ? () => setState(_clear) : null,
                child: const ArabicText('إخفاء الاقتراحات'),
              ),
          ],
        ),
      ),
    );
  }
}
