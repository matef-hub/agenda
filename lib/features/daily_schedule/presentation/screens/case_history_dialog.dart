import 'package:flutter/material.dart';

import '../../../../core/utils/arabic_format.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

class CaseHistoryDialog extends StatefulWidget {
  final Session session;
  const CaseHistoryDialog({super.key, required this.session});
  @override
  State<CaseHistoryDialog> createState() => _CaseHistoryDialogState();
}

class _CaseHistoryDialogState extends State<CaseHistoryDialog> {
  late Future<List<Session>> _history = SessionRepository().caseHistory(
    widget.session,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: ArabicText(
      'جلسات القضية ${widget.session.caseNumber} لسنة ${widget.session.caseYear}',
    ),
    content: SizedBox(
      width: 500,
      height: 350,
      child: FutureBuilder<List<Session>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ArabicText('تعذر تحميل سجل الجلسات.'),
                TextButton(
                  onPressed: () => setState(
                    () => _history = SessionRepository().caseHistory(
                      widget.session,
                    ),
                  ),
                  child: const ArabicText('إعادة المحاولة'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) {
              final session = snapshot.data![index];
              return ListTile(
                title: ArabicText(ArabicFormat.date(session.sessionDate)),
                subtitle: ArabicText(
                  '${session.decision.isEmpty ? 'لم يسجل قرار' : session.decision}\n${session.notes}',
                ),
              );
            },
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const ArabicText('إغلاق'),
      ),
    ],
  );
}
