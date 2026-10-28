import '../../../../core/utils/arabic_format.dart';
import 'session_model.dart';

/// A temporary input suggestion, never stored or linked to another hearing.
class HearingSuggestion {
  final List<Session> hearings;

  HearingSuggestion(Iterable<Session> records)
    : hearings = List.unmodifiable(
        records.toList()..sort((a, b) {
          final byDate = b.sessionDate.compareTo(a.sessionDate);
          return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
        }),
      );

  Session get latest => hearings.first;

  Session? lastDecisionBefore(DateTime date) {
    final day = ArabicFormat.day(date);
    for (final hearing in hearings) {
      if (ArabicFormat.day(hearing.sessionDate).isBefore(day) &&
          hearing.decision.trim().isNotEmpty) {
        return hearing;
      }
    }
    return null;
  }

  static List<HearingSuggestion> group(Iterable<Session> records) {
    final groups =
        <(String, String, String, String, String, String), List<Session>>{};
    String normalized(String value) => ArabicFormat.normalize(value).trim();
    for (final hearing in records) {
      final key = (
        normalized(hearing.caseNumber),
        normalized(hearing.caseYear.toString()),
        normalized(hearing.courtName),
        normalized(hearing.circuit),
        normalized(hearing.clientName),
        normalized(hearing.opponentName),
      );
      (groups[key] ??= []).add(hearing);
    }
    return groups.values.map(HearingSuggestion.new).toList()
      ..sort((a, b) => b.latest.sessionDate.compareTo(a.latest.sessionDate));
  }
}
